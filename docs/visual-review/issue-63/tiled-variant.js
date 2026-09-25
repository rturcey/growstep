// Run with: tiled --evaluate tiled-variant.js <canonical.tmx> <variant.tmx> <mode>
// Tiled's CLI scripting API edits the map in memory and writes a separate TMX.
var source = tiled.scriptArguments[0];
var output = tiled.scriptArguments[1];
var mode = tiled.scriptArguments[2];
if (!source || !output || source === output)
  throw new Error("Provide different source and output TMX paths");

var format = tiled.mapFormatForFile(source);
if (!format) throw new Error("No Tiled map format for " + source);
var map = format.read(source);
if (!map) throw new Error("Could not read " + source);

function layerNamed(name) {
  for (var i = 0; i < map.layerCount; ++i) {
    var layer = map.layerAt(i);
    if (layer.name === name) return layer;
  }
  throw new Error("Missing layer " + name);
}

if (mode === "rock-one-cell") {
  var props = layerNamed("props");
  var rock = null;
  for (var j = 0; j < props.objectCount; ++j) {
    var object = props.objectAt(j);
    if (object.name === "east_upper_rock") rock = object;
  }
  if (!rock || rock.y !== 220 || rock.property("gridRow") !== -8)
    throw new Error("Unexpected canonical rock position");
  rock.y += 40; // One native Tiled isometric object cell along the row axis.
  rock.setProperty("gridRow", -6); // Custom properties use half-cell units.
} else if (mode === "paint") {
  var path = layerNamed("path");
  if (path.tileAt(6, 10)) throw new Error("Target cell is already painted");
  var stamp = path.tileAt(6, 8);
  if (!stamp) throw new Error("Source stone tile is missing");
  var edit = path.edit();
  edit.setTile(6, 10, stamp);
  edit.apply();
} else if (mode === "depaint") {
  var path = layerNamed("path");
  if (!path.tileAt(8, 10)) throw new Error("Stone to erase is missing");
  var edit = path.edit();
  edit.setTile(8, 10, null);
  edit.apply();
} else {
  throw new Error("Unknown mode " + mode);
}

var error = format.write(map, output);
if (error) throw new Error(error);
tiled.log("Wrote " + mode + " to " + output);
