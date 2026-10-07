# Attribution and third-party content

## Application code and artwork

The independently written Swift application, HerbertCore, tests, scripts, documentation,
and original robot icon are licensed under the [MIT License](LICENSE).

## Original Herbert problems

`Sources/HerbertCore/Resources/problems.json` contains a snapshot of 1,769 public problems
from [Herbert Online Judge](http://herbert.tealang.info/problems.php), created by quolc
and its community. Each record preserves the original ID, title, credited author,
byte limit, source URL, and response SHA-256. Import provenance is recorded in
[the manifest](docs/problem-import-manifest.json). The snapshot was imported on October 7, 2026.

**The MIT license does not grant rights to this third-party problem archive.** No explicit
redistribution license was found on the original site or in
[quolc/hoj](https://github.com/quolc/hoj). Permission from the original rights holders
has not been confirmed. Original authors retain their rights. Public availability is
not a grant of an MIT license. The same distinction applies to the puzzle layouts
shown in the app screenshots in `docs/screenshots/`.

The gallery credits nai (Flower, #0037), snuke (Shuriken, #0027), and nadsuki
(Butterfly, #0361). These credits identify the authors listed by the original site;
they do not imply endorsement of this port.

To report an attribution error or a rights concern, contact the maintainer at
hugogu@outlook.com with the original problem ID and source. Please do not include
private information in a public issue.

## Rules and implementation

The H language and game behavior were independently implemented from the
[original rule description](http://herbert.tealang.info/rule.php).
[Rule notes](docs/rules.md) describe compatibility and execution limits.
The original Flash client and original server source are not included.
This is an independent community project, not an official release of Herbert Online Judge.
