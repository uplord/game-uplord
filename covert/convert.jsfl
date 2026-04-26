var dom = fl.getDocumentDOM();
var lib = dom.library;

// --------------------------------------
// BASE PROJECT PATH (next to FLA)
// --------------------------------------
var baseURI = dom.pathURI;
var baseFolder = baseURI.substring(0, baseURI.lastIndexOf("/") + 1);

// --------------------------------------
// SAFE CLEANUP: ONLY DELETE SYMBOL FOLDERS
// --------------------------------------
function clearSymbolFolders(baseFolder) {

    if (!FLfile.exists(baseFolder)) return;

    var folders = FLfile.listFolder(baseFolder, "directories");

    for (var i = 0; folders && i < folders.length; i++) {

        var folderPath = baseFolder + folders[i] + "/";

        clearFolderRecursive(folderPath);

        FLfile.remove(folderPath);
    }
}

function clearFolderRecursive(folderURI) {

    if (!FLfile.exists(folderURI)) return;

    var files = FLfile.listFolder(folderURI, "files");
    var folders = FLfile.listFolder(folderURI, "directories");

    for (var i = 0; files && i < files.length; i++) {
        FLfile.remove(folderURI + files[i]);
    }

    for (var j = 0; folders && j < folders.length; j++) {
        clearFolderRecursive(folderURI + folders[j] + "/");
        FLfile.remove(folderURI + folders[j] + "/");
    }
}

// ONLY remove symbol folders, NOT main files
clearSymbolFolders(baseFolder);

// --------------------------------------
// SANITIZE NAMES
// --------------------------------------
function sanitize(name) {
    return name.replace(/[^a-z0-9_\-]/gi, "_");
}

// --------------------------------------
// EXPORT SYMBOL FUNCTION
// --------------------------------------
function exportSymbol(item) {

    var name = sanitize(item.name);

    var folder = baseFolder + name + "/";
    FLfile.createFolder(folder);

    var filePath = folder + "armour.png";

    try {

        // Open symbol
        dom.library.editItem(item.name);

        dom.selectAll();

        if (!dom.selection || dom.selection.length === 0) {
            dom.exitEditMode();
            fl.trace("SKIP empty: " + item.name);
            return;
        }

        // Export PNG
        dom.exportPNG(filePath, true, true);

        dom.exitEditMode();

        fl.trace("OK: " + item.name);

    } catch (e) {
        try { dom.exitEditMode(); } catch (e2) {}
        fl.trace("FAILED: " + item.name + " -> " + e);
    }
}

// --------------------------------------
// MAIN LOOP
// --------------------------------------
for (var i = 0; i < lib.items.length; i++) {

    var item = lib.items[i];

    if (item.itemType === "movie clip" ||
        item.itemType === "graphic" ||
        item.itemType === "button") {

        exportSymbol(item);
    }
}

fl.trace("DONE: SAFE EXPORT COMPLETE");