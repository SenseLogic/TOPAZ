![](https://github.com/senselogic/OBSIDION/blob/master/LOGO/obsidion.png)

# Obsidion

Notion to Obsidian notebook converter.

## Installation

Install the [DMD 2 compiler](https://dlang.org/download.html) (using the MinGW setup option on Windows).

Build the executable with the following command line :

```bash
dmd -m64 obsidion.d
```

## Command line

```bash
obsidion {option} NOTION_EXPORT_FOLDER/ OBSIDIAN_VAULT_FOLDER/
```

### Options

```
--copy : move files
--move : move notes
```

### Examples

```bash
obsidion --copy NOTION_EXPORT_FOLDER/ OBSIDIAN_VAULT_FOLDER/
```

Copies the notes from the Notion export folder to the Obsidian vault folder.

```bash
obsidion --move NOTION_EXPORT_FOLDER/ OBSIDIAN_VAULT_FOLDER/
```

Moves the notes from the Notion export folder to the Obsidian vault folder.

## Version

0.0.1

## Author

Eric Pelzer (ecstatic.coder@gmail.com).

## License

This project is licensed under the GNU General Public License version 3.

See the [LICENSE.md](LICENSE.md) file for details.
