/*
 * Power BI mobile layout for PBIRS reports (injected at document start, in
 * every frame, before the report page's own scripts).
 *
 * PBIRS always draws a report's desktop layout in a browser. Its report page
 * downloads the report definition from
 *   /powerbi/api/explore/reports/<id>/modelsAndExploration
 * which, like the .pbix Report/Layout, lists every page ("sections") and
 * visual ("visualContainers", each with config.layouts: id 0 = desktop,
 * id 1 = phone). This script rewrites that download so the renderer draws the
 * phone layout instead:
 *   - visuals get their phone position, the others are dropped; desktop
 *     groups holding phone visuals are kept around them so bookmarks that
 *     show/hide groups (filter panels) keep working;
 *   - phone-only formatting (Report/MobileState "mobileObjects") is merged;
 *   - the page becomes a portrait canvas shown "fit to width".
 * Pages without a phone layout are left untouched (desktop view).
 *
 * Input: window.__PBI_MOBILE_LAYOUT__ = {pages: {<section name>: {width,
 * height, visuals: {<visual name>: {x, y, z, width, height, objects?}}}}}
 * extracted by the CBI backend from the .pbix. When absent, the phone
 * positions found in the download itself are used (without phone formatting).
 * Any unexpected shape leaves the response unchanged.
 */
(function () {
  'use strict';
  var root = typeof window !== 'undefined' ? window : globalThis;
  if (root.__pbiMobileLayoutInstalled) { return; }
  root.__pbiMobileLayoutInstalled = true;

  var PHONE_LAYOUT_ID = 1;
  var MIN_WIDTH = 320;
  var FIT_TO_WIDTH = 2;
  var TARGET = /\/api\/explore\/reports\/[^\/?#]+\/modelsandexploration/i;
  var stats = root.__pbiMobileLayoutStats = { rewritten: 0, pages: 0, errors: 0 };

  /* The rewrite happens in the report frame; expose the counters to the top page too. */
  function publish() {
    try { if (root.top && root.top !== root) { root.top.__pbiMobileLayoutStats = stats; } } catch (e) {}
  }

  function parseConfig(value) {
    if (value && typeof value === 'object') { return value; }
    if (typeof value === 'string' && value) {
      try { return JSON.parse(value); } catch (e) { return null; }
    }
    return null;
  }

  function phonePosition(config) {
    var layouts = (config && config.layouts) || [];
    for (var i = 0; i < layouts.length; i++) {
      if (layouts[i] && layouts[i].id === PHONE_LAYOUT_ID && layouts[i].position) { return layouts[i].position; }
    }
    return null;
  }

  /* Page map from the download itself (fallback without backend data). */
  function pageFromSection(section) {
    var visuals = {}, count = 0, width = MIN_WIDTH, height = 0;
    (section.visualContainers || []).forEach(function (container) {
      var config = parseConfig(container.config);
      var position = phonePosition(config);
      if (!config || !config.name || !position) { return; }
      visuals[config.name] = {
        x: position.x || 0, y: position.y || 0, z: position.z || 0,
        width: position.width || 0, height: position.height || 0
      };
      width = Math.max(width, (position.x || 0) + (position.width || 0));
      height = Math.max(height, (position.y || 0) + (position.height || 0));
      count++;
    });
    return count ? { width: width, height: height, visuals: visuals } : null;
  }

  function sameSelector(a, b) {
    return JSON.stringify(a || null) === JSON.stringify(b || null);
  }

  /* Phone formatting wins over desktop formatting, property by property. */
  function mergeObjects(objects, phoneObjects) {
    var merged = objects && typeof objects === 'object' ? objects : {};
    Object.keys(phoneObjects || {}).forEach(function (key) {
      var target = Array.isArray(merged[key]) ? merged[key] : (merged[key] = []);
      (phoneObjects[key] || []).forEach(function (entry) {
        if (!entry || !entry.properties) { return; }
        var existing = null;
        for (var i = 0; i < target.length; i++) {
          if (sameSelector(target[i] && target[i].selector, entry.selector)) { existing = target[i]; break; }
        }
        if (existing) {
          existing.properties = existing.properties || {};
          Object.keys(entry.properties).forEach(function (name) { existing.properties[name] = entry.properties[name]; });
        } else {
          target.push(JSON.parse(JSON.stringify(entry)));
        }
      });
    });
    return merged;
  }

  function setPosition(container, config, position) {
    container.x = position.x;
    container.y = position.y;
    container.z = position.z;
    container.width = position.width;
    container.height = position.height;
    config.layouts = [{ id: 0, position: position }];
  }

  /*
   * Visuals on the phone canvas get their phone position. Desktop groups that
   * contain some of them are KEPT (wrapped around their children's phone
   * positions) because bookmarks show/hide groups by name: e.g. a filter
   * panel hidden by default and toggled by "open/close filters" buttons.
   */
  function applyPage(section, page) {
    var entries = [];
    var byName = {};
    (section.visualContainers || []).forEach(function (container) {
      var config = parseConfig(container.config);
      var entry = { container: container, config: config, name: config && config.name };
      entries.push(entry);
      if (entry.name) { byName[entry.name] = entry; }
    });
    var keptVisuals = 0;
    var neededGroups = {};
    entries.forEach(function (entry) {
      var phone = entry.name && page.visuals[entry.name];
      if (!phone) { return; }
      entry.position = { x: phone.x, y: phone.y, z: phone.z, width: phone.width, height: phone.height };
      if (phone.objects && entry.config.singleVisual) {
        entry.config.singleVisual.objects = mergeObjects(entry.config.singleVisual.objects, phone.objects);
      }
      keptVisuals++;
      var parent = entry.config.parentGroupName, guard = 0;
      while (parent && byName[parent] && guard++ < 20) {
        neededGroups[parent] = true;
        parent = byName[parent].config.parentGroupName;
      }
    });
    if (!keptVisuals) { return false; }

    // Group bounds = union of their kept descendants (resolved deepest first).
    function bounds(name, depth) {
      var box = null;
      entries.forEach(function (entry) {
        if (!entry.config || entry.config.parentGroupName !== name) { return; }
        var child = entry.position || (neededGroups[entry.name] && depth < 20 ? bounds(entry.name, depth + 1) : null);
        if (!child) { return; }
        if (!box) { box = { x1: child.x, y1: child.y, x2: child.x + child.width, y2: child.y + child.height, z: child.z }; return; }
        box.x1 = Math.min(box.x1, child.x); box.y1 = Math.min(box.y1, child.y);
        box.x2 = Math.max(box.x2, child.x + child.width); box.y2 = Math.max(box.y2, child.y + child.height);
        box.z = Math.min(box.z, child.z);
      });
      return box && { x: box.x1, y: box.y1, z: box.z, width: box.x2 - box.x1, height: box.y2 - box.y1 };
    }

    var kept = [];
    entries.forEach(function (entry) {
      if (!entry.position && entry.name && neededGroups[entry.name]) { entry.position = bounds(entry.name, 0); }
      if (!entry.position) { return; } // not on the phone canvas
      // A parent group that is not kept (no phone visual under it) is dropped.
      if (entry.config.parentGroupName && !neededGroups[entry.config.parentGroupName]) { delete entry.config.parentGroupName; }
      setPosition(entry.container, entry.config, entry.position);
      entry.container.config = typeof entry.container.config === 'string' ? JSON.stringify(entry.config) : entry.config;
      kept.push(entry.container);
    });
    section.visualContainers = kept;
    section.width = Math.max(MIN_WIDTH, page.width || 0);
    section.height = page.height || section.height;
    section.displayOption = FIT_TO_WIDTH;
    return true;
  }

  function isSectionList(value) {
    return Array.isArray(value) && value.length > 0 && value.every(function (s) {
      return s && typeof s === 'object' && Array.isArray(s.visualContainers);
    });
  }

  /* Rewrites every page list found in the payload; returns the number of pages changed. */
  function transform(payload, layout) {
    var pages = (layout && layout.pages) || null;
    var changed = 0, seen = [];
    (function walk(node, depth) {
      if (!node || typeof node !== 'object' || depth > 8 || seen.indexOf(node) >= 0) { return; }
      seen.push(node);
      Object.keys(node).forEach(function (key) {
        var value = node[key];
        if (key === 'sections' && isSectionList(value)) {
          value.forEach(function (section) {
            var page = (pages && pages[section.name]) || (!pages && pageFromSection(section));
            if (page && applyPage(section, page)) { changed++; }
          });
        } else if (typeof value === 'string' && value.charAt(0) === '{' && key === 'exploration') {
          // Some versions nest the definition as a JSON string.
          var nested = parseConfig(value);
          if (nested) {
            var before = changed;
            walk(nested, depth + 1);
            if (changed > before) { node[key] = JSON.stringify(nested); }
          }
        } else if (value && typeof value === 'object') {
          walk(value, depth + 1);
        }
      });
    })(payload, 0);
    return changed;
  }

  function rewriteText(text) {
    try {
      var payload = JSON.parse(text);
      var changed = transform(payload, root.__PBI_MOBILE_LAYOUT__);
      if (!changed) { return text; }
      stats.rewritten++;
      stats.pages += changed;
      publish();
      return JSON.stringify(payload);
    } catch (e) {
      stats.errors++;
      publish();
      return text;
    }
  }

  root.__pbiMobileLayoutTransform = transform; // exposed for tests

  if (typeof root.fetch === 'function') {
    var originalFetch = root.fetch;
    root.fetch = function (input, init) {
      var url = typeof input === 'string' ? input : (input && input.url) || '';
      var request = originalFetch.apply(this, arguments);
      if (!TARGET.test(url)) { return request; }
      return request.then(function (response) {
        if (!response || !response.ok) { return response; }
        return response.clone().text().then(function (text) {
          var rewritten = rewriteText(text);
          if (rewritten === text) { return response; }
          return new Response(rewritten, { status: response.status, statusText: response.statusText, headers: response.headers });
        }, function () { return response; });
      });
    };
  }

  var Xhr = root.XMLHttpRequest;
  if (Xhr && Xhr.prototype) {
    var originalOpen = Xhr.prototype.open;
    Xhr.prototype.open = function (method, url) {
      this.__pbiTarget = TARGET.test(String(url || ''));
      return originalOpen.apply(this, arguments);
    };
    ['responseText', 'response'].forEach(function (property) {
      var descriptor = Object.getOwnPropertyDescriptor(Xhr.prototype, property);
      if (!descriptor || !descriptor.get) { return; }
      Object.defineProperty(Xhr.prototype, property, {
        configurable: true,
        enumerable: descriptor.enumerable,
        get: function () {
          var value = descriptor.get.call(this);
          if (!this.__pbiTarget || this.readyState !== 4 || this.status < 200 || this.status >= 300) { return value; }
          if (this.__pbiSource === value && this.__pbiResult !== undefined) { return this.__pbiResult; }
          var result = value;
          if (typeof value === 'string') {
            result = rewriteText(value);
          } else if (value && typeof value === 'object' && !(value instanceof ArrayBuffer)) {
            try {
              var changed = transform(value, root.__PBI_MOBILE_LAYOUT__);
              if (changed) { stats.rewritten++; stats.pages += changed; publish(); }
            } catch (e) { stats.errors++; publish(); }
          }
          this.__pbiSource = value;
          this.__pbiResult = result;
          return result;
        }
      });
    });
  }
})();
