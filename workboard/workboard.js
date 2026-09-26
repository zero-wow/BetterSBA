(() => {
  "use strict";

  const project = window.WORKBOARD_PROJECT;
  if (!project || !Array.isArray(project.items)) {
    document.body.textContent = "Workboard data is missing. Load project.js beside index.html.";
    return;
  }

  const lanes = ["Add", "Fix", "Reimagine", "Polish"];
  const states = ["All", "Next", "Verify", "Backlog", "Done"];
  const ids = new Set();
  for (const item of project.items) {
    if (!item.id || ids.has(item.id) || !lanes.includes(item.lane) || !states.includes(item.state)) {
      throw new Error(`Invalid Workboard item: ${item.id || "missing ID"}`);
    }
    ids.add(item.id);
  }

  const $ = id => document.getElementById(id);
  const items = project.items;
  const storageKey = `workboard:${project.key || project.name}:theme`;
  const requestedSelection = decodeURIComponent(location.hash.slice(1)) || project.spotlight || items[0]?.id;
  const initialSelection = items.find(item => item.id === requestedSelection) || items[0];
  const state = {
    lane: initialSelection?.lane || "All",
    status: "All",
    query: "",
    selected: initialSelection?.id,
    theme: project.defaultTheme === "horde" ? "horde" : "alliance"
  };

  try {
    const savedTheme = localStorage.getItem(storageKey);
    if (savedTheme === "horde" || savedTheme === "alliance") state.theme = savedTheme;
  } catch (_) { /* file:// storage may be unavailable */ }

  const make = (tag, className, text) => {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  };

  function setTheme(theme) {
    state.theme = theme;
    document.body.dataset.theme = theme;
    $("allianceTheme").setAttribute("aria-pressed", String(theme === "alliance"));
    $("hordeTheme").setAttribute("aria-pressed", String(theme === "horde"));
    $("factionHero").src = `assets/${theme === "horde" ? "Horde" : "Alliance"}TalentHero.png`;
    $("factionHero").alt = `${theme === "horde" ? "Horde" : "Alliance"} comic-book character and banner`;
    try { localStorage.setItem(storageKey, theme); } catch (_) { /* private or file storage */ }
  }

  function scopedItems() {
    const query = state.query.trim().toLocaleLowerCase();
    return items.filter(item =>
      (state.lane === "All" || item.lane === state.lane) &&
      (!query || [item.id, item.title, item.summary, item.doneWhen, item.lane, item.priority]
        .some(value => String(value || "").toLocaleLowerCase().includes(query)))
    );
  }

  function filteredItems() {
    return scopedItems().filter(item => state.status === "All" || item.state === state.status);
  }

  function renderNav() {
    const nav = $("laneNav");
    nav.replaceChildren();
    for (const [index, lane] of ["All", ...lanes].entries()) {
      const count = lane === "All" ? items.length : items.filter(item => item.lane === lane).length;
      const button = make("button", "lane-button");
      button.type = "button";
      button.setAttribute("aria-current", String(state.lane === lane));
      button.append(
        make("span", "lane-index", String(index).padStart(2, "0")),
        make("span", "lane-name", lane === "All" ? "All Missions" : lane),
        make("span", "lane-count", String(count).padStart(2, "0"))
      );
      button.addEventListener("click", () => {
        state.lane = lane;
        state.status = "All";
        render();
      });
      nav.append(button);
    }
  }

  function renderStateFilters() {
    const target = $("stateFilters");
    target.replaceChildren();
    const scope = scopedItems();
    for (const name of states) {
      const count = name === "All" ? scope.length : scope.filter(item => item.state === name).length;
      const button = make("button", "", `${name} ${count}`);
      button.type = "button";
      button.setAttribute("aria-pressed", String(state.status === name));
      button.addEventListener("click", () => {
        state.status = name;
        render();
      });
      target.append(button);
    }
  }

  function selectItem(id, updateHash = true) {
    const item = items.find(candidate => candidate.id === id);
    if (!item) return;
    state.selected = id;
    if (updateHash) {
      try { history.replaceState(null, "", `#${encodeURIComponent(id)}`); }
      catch (_) { location.hash = encodeURIComponent(id); }
    }
    $("inspectorId").textContent = item.id;
    $("inspectorHeading").textContent = item.title;
    $("inspectorSummary").textContent = item.summary;
    $("inspectorLane").textContent = item.lane;
    $("inspectorPriority").textContent = item.priority;
    $("inspectorState").textContent = item.state;
    $("inspectorDoneWhen").textContent = item.doneWhen;
    $("inspectorEvidence").textContent = item.evidence || "";
    $("evidenceBox").hidden = !item.evidence;
    document.querySelectorAll(".mission-row").forEach(row =>
      row.setAttribute("aria-pressed", String(row.dataset.id === id)));
  }

  function missionRow(item) {
    const row = make("button", "mission-row");
    row.type = "button";
    row.dataset.id = item.id;
    row.setAttribute("aria-pressed", String(state.selected === item.id));
    row.setAttribute("aria-label", `${item.id}: ${item.title}. ${item.state}. ${item.priority} priority.`);
    const copy = make("span", "mission-text");
    copy.append(make("span", "mission-title", item.title), make("span", "mission-summary", item.summary));
    const tail = make("span", "mission-tail");
    const priority = make("span", "priority", item.priority);
    priority.dataset.priority = item.priority;
    const pill = make("span", "state-pill", item.state);
    pill.dataset.state = item.state;
    tail.append(priority, pill);
    row.append(make("span", "mission-index", item.id.slice(1)), copy, tail);
    row.addEventListener("click", () => selectItem(item.id));
    return row;
  }

  function renderList() {
    const visible = filteredItems();
    const target = $("missionList");
    target.replaceChildren();
    $("visibleCount").textContent = `${visible.length} Showing`;
    $("noResults").hidden = visible.length > 0;
    for (const lane of lanes) {
      const groupItems = visible.filter(item => item.lane === lane);
      if (!groupItems.length) continue;
      const group = make("section", "lane-group");
      group.dataset.lane = lane;
      const heading = make("h3", "lane-group-heading", lane);
      heading.append(make("span", "", `${groupItems.length} Missions`));
      group.append(heading, ...groupItems.map(missionRow));
      target.append(group);
    }
    if (visible.length && !visible.some(item => item.id === state.selected)) {
      selectItem(visible[0].id);
    } else if (state.selected) {
      selectItem(state.selected, false);
    }
  }

  function render() {
    renderNav();
    renderStateFilters();
    renderList();
  }

  function renderActivity() {
    const activity = Array.isArray(project.activity) ? project.activity : [];
    $("activityFeed").hidden = activity.length === 0;
    const list = $("activityList");
    list.replaceChildren();
    for (const event of activity.slice(0, 3)) {
      if (!ids.has(event.id)) continue;
      const button = make("button", "activity-item");
      button.type = "button";
      button.setAttribute("aria-label", `${event.id}: ${event.text}`);
      button.append(make("span", "activity-date", event.date),
        make("span", "activity-id", event.id),
        make("span", "activity-text", event.text));
      button.addEventListener("click", () => {
        state.lane = "All";
        state.status = "All";
        state.query = "";
        $("searchInput").value = "";
        render();
        selectItem(event.id);
      });
      list.append(button);
    }
  }

  $("brandName").textContent = "Workboard";
  $("projectName").textContent = project.name;
  $("boardTitle").replaceChildren(document.createTextNode(`${project.name} `), make("em", "", "Workboard"));
  $("projectSubtitle").textContent = project.subtitle;
  $("footerProject").textContent = project.name;
  $("footerCount").textContent = `${items.length} Missions`;
  $("updateStamp").textContent = `Updated ${project.updated}`;
  const done = items.filter(item => item.state === "Done").length;
  $("doneCount").textContent = String(done);
  $("totalCount").textContent = String(items.length);
  $("progressTrack").setAttribute("aria-valuemax", String(items.length));
  $("progressTrack").setAttribute("aria-valuenow", String(done));
  requestAnimationFrame(() => { $("progressFill").style.width = `${items.length ? done / items.length * 100 : 0}%`; });
  document.title = `${project.name} — Workboard`;

  $("allianceTheme").addEventListener("click", () => setTheme("alliance"));
  $("hordeTheme").addEventListener("click", () => setTheme("horde"));
  $("searchInput").addEventListener("input", event => { state.query = event.target.value; renderStateFilters(); renderList(); });
  document.addEventListener("keydown", event => {
    if (event.key === "/" && !/^(INPUT|TEXTAREA)$/.test(document.activeElement.tagName)) {
      event.preventDefault(); $("searchInput").focus();
    }
    if (event.key === "Escape" && document.activeElement === $("searchInput")) {
      $("searchInput").value = ""; state.query = ""; renderStateFilters(); renderList(); $("searchInput").blur();
    }
  });
  window.addEventListener("hashchange", () => selectItem(decodeURIComponent(location.hash.slice(1)), false));
  $("copyLink").addEventListener("click", async () => {
    const button = $("copyLink");
    const label = button.querySelector("span");
    const url = `${location.href.split("#")[0]}#${encodeURIComponent(state.selected)}`;
    try {
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(url);
      } else {
        const field = make("textarea");
        field.value = url;
        document.body.append(field);
        field.select();
        const copied = document.execCommand("copy");
        field.remove();
        if (!copied) throw new Error("Clipboard unavailable");
      }
      label.textContent = "Link Copied";
    } catch (_) {
      label.textContent = "Link Unavailable";
    }
    setTimeout(() => { label.textContent = "Copy Mission Link"; }, 1800);
  });
  $("downloadSnapshot").addEventListener("click", () => {
    const blob = new Blob([JSON.stringify(project, null, 2)], {type:"application/json"});
    const url = URL.createObjectURL(blob);
    const link = make("a");
    link.href = url;
    link.download = `${project.key || "project"}-workboard-${project.updated}.json`;
    link.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  });

  setTheme(state.theme);
  renderActivity();
  render();
})();
