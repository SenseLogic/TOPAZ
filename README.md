![](https://github.com/senselogic/TOPAZ/blob/master/LOGO/topaz.png)

# Topaz

Notion to Obsidian notebook converter.

## Installation

Install the [DMD 2 compiler](https://dlang.org/download.html) (using the MinGW setup option on Windows).

Build the executable with the following command line :

```bash
dmd -m64 topaz.d
```

## Command line

```bash
topaz [options] NOTION_EXPORT_FOLDER/ OBSIDIAN_VAULT_FOLDER/
topaz [options] OBSIDIAN_VAULT_FOLDER/
```


### Options

```
--fix-paths : fix paths
--fix-newlines : fix newlines
--fix-video-links : fix video links
--fix-titles : fix titles
--fix-indexes : fix indexes
```

Removing the note UUID requires to copy the notes between two different folders.

### Examples

```bash
topaz --fix-paths --fix-newlines --fix-video-links --fix-titles --fix-indexes NOTION_EXPORT_FOLDER/ OBSIDIAN_VAULT_FOLDER/
```

Copies notes and their media files from the Notion export folder to the Obsidian vault folder, fixing paths, newlines, video links, titles and indexes.

```bash
topaz --fix-newlines --fix-video-links --fix-titles --fix-indexes OBSIDIAN_VAULT_FOLDER/
```

Fixes newlines, video links, titles and indexes of the Obsidian vault folder notes.

## Version

1.0

## Author

Eric Pelzer (ecstatic.coder@gmail.com).

## License

This project is licensed under the GNU General Public License version 3.

See the [LICENSE.md](LICENSE.md) file for details.
