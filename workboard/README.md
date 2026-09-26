# Comic Workboard

Open `index.html` in a desktop browser. It works offline and needs no build step, account, or server. The default view opens the current spotlight mission; use the lane rail, state filters, search, and Alliance/Horde switch to explore the backlog. Click a mission to see its acceptance check and copy a link to it. The theme choice is saved locally in the browser.

On this machine, [bettersba-workboard.lan](http://bettersba-workboard.lan/) serves this folder through the `W:\bettersba-workboard` Laragon junction. Changes to the source-controlled board appear after refreshing the page.

This folder is portable. To use it for another project, copy the whole `workboard` folder and replace the `window.WORKBOARD_PROJECT` object in `project.js`. Keep the item fields `id`, `lane`, `title`, `priority`, `state`, `summary`, and `doneWhen`; `evidence` is optional. The four lanes are Add, Fix, Reimagine, and Polish. States are Next, Verify, Backlog, and Done. Change `spotlight` to an existing item ID. Replace the faction art in `assets` only if the new project needs different imagery; the interface and behavior do not depend on BetterSBA code.

The board is source-controlled. Update `project.js` when work changes state, add a short evidence note for work awaiting in-game verification, then refresh the page. Browser filters and the selected mission are display choices; they do not silently rewrite the backlog. **Download Snapshot** exports the current project data as JSON.

The supplied Bangers and Lilita One fonts carry their SIL Open Font License notices in `assets`. Most faction artwork is copied from BetterSBA's comic assets; the Alliance hero is the approved, already-composited crop supplied for this board.
