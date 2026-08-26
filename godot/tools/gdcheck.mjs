#!/usr/bin/env node
// A static check for the GDScript in this project.
//
// No Godot runs in the environment the port was written in, so this catches the errors
// that would otherwise only surface on first open: unbalanced brackets, mixed
// indentation, calls to methods that do not exist on the class, references to unknown
// class_names, and Godot 3 API that no longer resolves in 4.
import fs from 'fs';
import path from 'path';

const root = process.argv[2] || '.';
const files = [];
(function walk(d) {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    const p = path.join(d, e.name);
    if (e.isDirectory()) walk(p);
    else if (e.name.endsWith('.gd')) files.push(p);
  }
})(root);

// Godot 3 names that were renamed or removed in 4.
const GODOT3 = [
  ['(?<!@)\\bexport\\s*\\(', '@export'],
  ['(?<!@)\\bonready\\s+var', '@onready var'],
  ['^\\s*tool\\s*$', '@tool'],
  ['(?<!\\w)yield\\s*\\(', 'await'],
  ['\\bKinematicBody2D\\b', 'CharacterBody2D'],
  ['\\bSpatial\\b', 'Node3D'],
  ['\\.instance\\s*\\(\\s*\\)', 'instantiate()'],
  ['(?<!is_)\\bempty\\s*\\(\\s*\\)', 'is_empty()'],
  ['\\bconnect\\s*\\(\\s*"', 'signal.connect(callable)'],
  ['\\bPoolStringArray\\b', 'PackedStringArray'],
  ['\\brand_range\\b', 'randf_range'],
  ['\\bOS\\.get_ticks_msec\\b', 'Time.get_ticks_msec'],
  ['(?<!queue_redraw)(?<!\\bRun)\\.update\\s*\\(\\s*\\)', 'queue_redraw()'],
];

const classes = new Map();   // class_name -> { file, members:Set, methods:Set, statics:Set }
const perFile = new Map();

for (const f of files) {
  const src = fs.readFileSync(f, 'utf8');
  const lines = src.split('\n');
  const cn = (src.match(/^class_name\s+(\w+)/m) || [])[1];
  const info = { file: f, members: new Set(), methods: new Set(), statics: new Set(),
                 consts: new Set(), src, lines };
  for (const l of lines) {
    let m;
    if ((m = l.match(/^\s*(?:@export[^\n]*\s+)?var\s+(\w+)/))) info.members.add(m[1]);
    if ((m = l.match(/^\s*const\s+(\w+)/))) info.consts.add(m[1]);
    if ((m = l.match(/^\s*static\s+func\s+(\w+)/))) info.statics.add(m[1]);
    else if ((m = l.match(/^\s*func\s+(\w+)/))) info.methods.add(m[1]);
  }
  perFile.set(f, info);
  if (cn) classes.set(cn, info);
}

// Blank out string literals, then drop the trailing comment.
function strip(line) {
  return line.replace(/"(\\.|[^"\\])*"/g, '""').replace(/'(\\.|[^'\\])*'/g, "''")
             .replace(/#.*$/, '');
}

// Built-ins every Object/RefCounted has, so a call to one is never a missing method.
const BUILTIN = new Set(['new','duplicate','get','set','call','has_method','free',
  'get_class','is_class','connect','emit','resource_path','instantiate']);

const problems = [];
const add = (f, i, msg) => problems.push(`${path.relative(root, f)}:${i + 1}  ${msg}`);

for (const [f, info] of perFile) {
  const { lines } = info;
  let depth = 0;
  lines.forEach((l, i) => {
    // strings first, THEN comments — otherwise Color("#6fbf5b") loses its paren
    const code = strip(l);
    for (const ch of code) {
      if ('([{'.includes(ch)) depth++;
      if (')]}'.includes(ch)) depth--;
      if (depth < 0) { add(f, i, 'closing bracket with nothing open'); depth = 0; }
    }
    if (/^\t* +\S/.test(l)) add(f, i, 'spaces used for indentation after tabs');
    if (/^ +\t/.test(l)) add(f, i, 'tab after spaces');
    for (const [pat, fix] of GODOT3) {
      if (new RegExp(pat).test(code)) add(f, i, `Godot 3 API — use ${fix}`);
    }
    // a `func` line that is followed by a line at the same or lower indent
    if (/^\s*(static\s+)?func\s+\w+.*:\s*$/.test(l)) {
      const ind = (l.match(/^\t*/) || [''])[0].length;
      const next = lines.slice(i + 1).find(x => x.trim() && !x.trim().startsWith('#'));
      if (next && (next.match(/^\t*/) || [''])[0].length <= ind) add(f, i, 'function body is empty');
    }
  });
  if (depth !== 0) add(f, lines.length - 1, `file ends with ${depth} bracket(s) unclosed`);
}

// Cross-file: Type.method() where Type is one of ours
const known = new Set([...classes.keys()]);
for (const [f, info] of perFile) {
  info.lines.forEach((l, i) => {
    const code = strip(l);
    let m;
    const re = /\b([A-Z]\w+)\.(\w+)\s*\(/g;
    while ((m = re.exec(code))) {
      const [_, type, method] = m;
      if (!known.has(type)) continue;
      const c = classes.get(type);
      if (BUILTIN.has(method)) continue;
      if (!c.statics.has(method) && !c.methods.has(method) && !c.consts.has(method))
        add(f, i, `${type}.${method}() is not defined in ${path.basename(c.file)}`);
    }
    // self-calls
    const re2 = /(?:^|[^.\w])(_?[a-z]\w*)\s*\(/g;
    while ((m = re2.exec(code))) {
      const name = m[1];
      if (!name.startsWith('_')) continue;
      if (info.methods.has(name) || info.statics.has(name)) continue;
      if (['_init','_ready','_process','_draw','_input','_notification','_physics_process',
           '_gui_input','_unhandled_input','_to_string','_get','_set'].includes(name)) continue;
      add(f, i, `calls ${name}() which is not defined in this file`);
    }
  });
}

console.log(`checked ${files.length} GDScript files, ${[...classes.keys()].length} classes: ${[...classes.keys()].join(', ')}`);
if (!problems.length) console.log('no problems found');
else { console.log(`${problems.length} problem(s):`); for (const p of problems) console.log('  ' + p); }
process.exit(problems.length ? 1 : 0);
