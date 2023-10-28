/*
    This file is part of the Topaz distribution.

    https://github.com/senselogic/TOPAZ

    Copyright (C) 2023 Eric Pelzer (ecstatic.coder@gmail.com)

    Topaz is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, version 3.

    Topaz is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Topaz.  If not, see <http://www.gnu.org/licenses/>.
*/

// -- IMPORTS

import core.stdc.stdlib : exit;
import std.algorithm : canFind;
import std.conv : to;
import std.file : copy, dirEntries, exists, mkdirRecurse, readText, write, SpanMode;
import std.path : absolutePath;
import std.regex : matchAll, matchFirst, regex, replaceAll;
import std.stdio : writeln, File;
import std.string : endsWith, indexOf, join, lastIndexOf, replace, split, startsWith, strip;

// -- TYPES

class FILE
{
    // -- ATTRIBUTES

    FOLDER[]
        FolderArray;
    FOLDER
        Folder;
    string
        OldName,
        NewName,
        Extension;
    bool
        IsFixed,
        IsRenamed;

    // -- CONSTRUCTORS

    this(
        string file_path
        )
    {
        OldName = file_path.GetFileName();
        Extension = file_path.GetFileExtension();
        FolderArray = GetFolderArray( file_path.GetFolderPath() );
        Folder = FolderArray[ $ - 1 ];
        Folder.FileArray ~= this;

        IsFixed
            = ( Extension == ".md"
                || Extension == ".csv" );

        IsRenamed
            = ( IsFixed
                && OldName.HasUuidSuffix() );

        if ( IsRenamed )
        {
            NewName = OldName.FixPathsSuffix();
        }
        else
        {
            NewName = OldName;
        }

        .FileArray ~= this;
    }

    // -- INQUIRIES

    string GetOldLabel(
        )
    {
        return OldName ~ Extension;
    }

    // ~~

    string GetNewLabel(
        )
    {
        return NewName ~ Extension;
    }

    // ~~

    string GetOldPath(
        )
    {
        return Folder.GetOldPath() ~ GetOldLabel();
    }

    // ~~

    string GetNewPath(
        )
    {
        return Folder.GetNewPath() ~ GetNewLabel();
    }

    // ~~

    string GetMatchingFolderPath(
        )
    {
        return Folder.GetNewPath() ~ NewName ~ '/';
    }

    // ~~

    void Dump(
        )
    {
        writeln( GetOldPath(), "\n", GetNewPath(), "\n" );
    }

    // -- OPERATIONS

    void Copy(
        )
    {
        CopyFile(
            GetFullPath( .OldFolderPath, GetOldPath() ),
            GetFullPath( .NewFolderPath, GetNewPath() )
            );
    }

    // ~~

    void FixPaths(
        ref string file_text
        )
    {
        string[]
            uuid_suffix_array;
        FILE*
            found_file;
        FOLDER*
            found_folder;

        foreach ( match; file_text.matchAll( UuidSuffixRegularExpression ) )
        {
            uuid_suffix_array ~= " " ~ match.hit[ 3 .. $ ];
        }

        foreach ( uuid_suffix; uuid_suffix_array )
        {
            found_folder = ( uuid_suffix in FolderByUuidSuffixMap );

            if ( found_folder !is null )
            {
                file_text = file_text.replace( found_folder.OldName, found_folder.NewName );
            }
        }

        foreach ( uuid_suffix; uuid_suffix_array )
        {
            found_file = ( uuid_suffix in FileByUuidSuffixMap );

            if ( found_file !is null )
            {
                file_text
                    = file_text.replace(
                          found_file.OldName.GetEncodedName(),
                          found_file.NewName.GetEncodedName()
                          );
            }
        }
    }

    // ~~

    void FixNewlines(
        ref string file_text
        )
    {
        file_text = file_text.replace( "\r", "" );
    }

    // ~~

    void FixVideoLinks(
        ref string file_text
        )
    {
        file_text = file_text.replaceAll( VideoLinkRegularExpressions, r"![[$1]]" );
    }

    // ~~

    void FixTitles(
        ref string file_text
        )
    {
        string
            file_title;

        FixNewlines( file_text );

        while ( file_text.startsWith( '\n' ) )
        {
            file_text = file_text[ 1 .. $ ];
        }

        file_title = "# " ~ NewName ~ "\n";

        if ( file_text.startsWith( file_title ) )
        {
            file_text = file_text[ file_title.length .. $ ];
        }

        while ( file_text.startsWith( '\n' ) )
        {
            file_text = file_text[ 1 .. $ ];
        }
    }

    // ~~

    void FixIndexes(
        ref string file_text
        )
    {
        long
            line_index;
        string
            file_link,
            matching_folder_path,
            stripped_line;
        string[]
            line_array;
        FILE[ string ]
            file_by_link_map;
        FOLDER*
            matching_folder;

        FixNewlines( file_text );

        matching_folder_path = GetMatchingFolderPath();
        matching_folder = matching_folder_path in FolderByNewFolderPathMap;

        if ( matching_folder !is null )
        {
            foreach ( file; matching_folder.FileArray )
            {
                if ( file.Extension == ".md" )
                {
                    file_link
                        = "["
                          ~ file.NewName
                          ~ "]("
                          ~ NewName.GetEncodedName()
                          ~ "/"
                          ~ file.NewName.GetEncodedName()
                          ~ ".md)";

                    file_by_link_map[ file_link ] = file;
                }
            }

            line_array = file_text.split( '\n' );

            for ( line_index = 0;
                  line_index < line_array.length;
                  ++line_index )
            {
                stripped_line = line_array[ line_index ].strip();

                if ( stripped_line.IsLinkLine() )
                {
                    if ( ( stripped_line in file_by_link_map ) !is null )
                    {
                        line_array
                            = line_array[ 0 .. line_index ]
                              ~ line_array[ line_index + 1 .. $ ];

                        --line_index;
                    }
                }
                else if ( stripped_line == "" )
                {
                    line_array
                        = line_array[ 0 .. line_index ]
                          ~ line_array[ line_index + 1 .. $ ];

                    --line_index;
                }
                else
                {
                    break;
                }
            }

            file_text = line_array.join( '\n' );
        }
    }

    // ~~

    void Fix(
        )
    {
        string
            file_path,
            file_text;

        if ( IsFixed )
        {
            file_path = GetFullPath( .NewFolderPath, GetNewPath() );
            file_text = file_path.ReadText();

            if ( FixPathsOptionIsEnabled )
            {
                FixPaths( file_text );
            }

            if ( Extension == ".md" )
            {
                if ( FixNewlinesOptionIsEnabled )
                {
                    FixNewlines( file_text );
                }

                if ( FixVideoLinksOptionIsEnabled )
                {
                    FixVideoLinks( file_text );
                }

                if ( FixTitlesOptionIsEnabled )
                {
                    FixTitles( file_text );
                }

                if ( FixIndexesOptionIsEnabled )
                {
                    FixIndexes( file_text );
                }
            }

            file_path.WriteText( file_text );
        }
    }
}

// ~~

class FOLDER
{
    // -- ATTRIBUTES

    FOLDER
        SuperFolder;
    string
        OldName,
        NewName;
    FILE[]
        FileArray;
    FOLDER[]
        SubFolderArray;
    bool
        IsRenamed;

    // -- CONSTRUCTORS

    this(
        string folder_path,
        string[] folder_name_array
        )
    {
        string
            super_folder_path;

        OldName = folder_path.GetFolderName();

        .FolderArray ~= this;
        .FolderByOldFolderPathMap[ folder_path ] = this;

        if ( folder_name_array.length > 1 )
        {
            super_folder_path = folder_name_array[ 0 .. $ - 1 ].GetFolderPath();

            SuperFolder = .FolderByOldFolderPathMap[ super_folder_path ];
            SuperFolder.SubFolderArray ~= this;
        }

        IsRenamed = OldName.HasUuidSuffix();

        if ( IsRenamed )
        {
            NewName = OldName.FixPathsSuffix();
        }
        else
        {
            NewName = OldName;
        }
    }

    // -- INQUIRIES

    string GetOldPath(
        )
    {
        string
            old_path;
        FOLDER
            folder;

        for ( folder = this;
              folder !is null;
              folder = folder.SuperFolder )
        {
            old_path = folder.OldName ~ '/' ~ old_path;
        }

        return old_path;
    }

    // ~~

    string GetNewPath(
        )
    {
        string
            new_path;
        FOLDER
            folder;

        for ( folder = this;
              folder !is null;
              folder = folder.SuperFolder )
        {
            new_path = folder.NewName ~ '/' ~ new_path;
        }

        return new_path;
    }

    // ~~

    void Dump(
        )
    {
        writeln( GetOldPath(), "\n", GetNewPath, "\n" );
    }

    // ~~

    void DumpFiles(
        bool sub_folders_are_dumped = true
        )
    {
        Dump();

        foreach ( file; FileArray )
        {
            file.Dump();
        }

        if ( sub_folders_are_dumped )
        {
            foreach ( sub_folder; SubFolderArray )
            {
                sub_folder.DumpFiles( sub_folders_are_dumped );
            }
        }
    }

    // -- OPERATIONS

    void RenameFiles(
        )
    {
        string
            base_old_name,
            fixed_new_name;
        string[ string ]
            fixed_new_name_by_old_name_map;
        string[][ string ]
            old_name_array_by_new_name_map;

        foreach ( file; FileArray )
        {
            if ( file.IsRenamed )
            {
                if ( ( file.NewName in old_name_array_by_new_name_map ) == null
                     || !old_name_array_by_new_name_map[ file.NewName ].canFind( file.OldName ) )
                {
                    old_name_array_by_new_name_map[ file.NewName ] ~= file.OldName;
                }
            }
        }

        foreach ( sub_folder; SubFolderArray )
        {
            if ( sub_folder.IsRenamed )
            {
                if ( ( sub_folder.NewName in old_name_array_by_new_name_map ) == null
                     || !old_name_array_by_new_name_map[ sub_folder.NewName ].canFind( sub_folder.OldName ) )
                {
                    old_name_array_by_new_name_map[ sub_folder.NewName ] ~= sub_folder.OldName;
                }
            }
        }

        foreach ( new_name, old_name_array; old_name_array_by_new_name_map )
        {
            foreach ( old_name_index, old_name; old_name_array )
            {
                if ( old_name_index == 0 )
                {
                    fixed_new_name = new_name;
                }
                else
                {
                    fixed_new_name = new_name ~ " (" ~ ( old_name_index + 1 ).to!string() ~ ")";
                }

                fixed_new_name_by_old_name_map[ old_name ] = fixed_new_name;
            }
        }

        foreach ( file; FileArray )
        {
            if ( file.IsRenamed )
            {
                file.NewName = fixed_new_name_by_old_name_map[ file.OldName ];

                FileByUuidSuffixMap[ file.OldName.GetUuidSuffix ] = file;
            }
            else if ( file.OldName.endsWith( "_all" )
                      && file.Extension == ".csv" )
            {
                base_old_name = file.OldName[ 0 .. $ - 4 ];

                if ( ( base_old_name in fixed_new_name_by_old_name_map ) != null )
                {
                    file.NewName = fixed_new_name_by_old_name_map[ base_old_name ] ~ "_all";
                }
            }
        }

        foreach ( sub_folder; SubFolderArray )
        {
            if ( sub_folder.IsRenamed )
            {
                sub_folder.NewName = fixed_new_name_by_old_name_map[ sub_folder.OldName ];

                FolderByUuidSuffixMap[ sub_folder.OldName.GetUuidSuffix ] = sub_folder;
            }
        }

        foreach ( sub_folder; SubFolderArray )
        {
            sub_folder.RenameFiles();
        }
    }

    // ~~

    void CopyFiles(
        )
    {
        foreach ( file; FileArray )
        {
            file.Copy();
        }

        foreach ( sub_folder; SubFolderArray )
        {
            sub_folder.CopyFiles();
        }
    }

    // ~~

    void FixFiles(
        )
    {
        foreach ( file; FileArray )
        {
            file.Fix();
        }

        foreach ( sub_folder; SubFolderArray )
        {
            sub_folder.FixFiles();
        }
    }
}

// -- CONSTANTS

auto
    LinkLineRegularExpression = regex( r"^\[.+\]\(.+.md\)$" ),
    UuidSuffixRegularExpression = regex( "%20[0-9a-f]{32}" ),
    UuidSuffixedNameRegularExpression = regex( "^.+ [0-9a-f]{32}$" ),
    VideoLinkRegularExpressions = regex( r"\[[^\[\]]*\]\(([^\(\)]+\.mp4)\)" );

// -- VARIABLES

bool
    FixIndexesOptionIsEnabled,
    FixPathsOptionIsEnabled,
    FixNewlinesOptionIsEnabled,
    FixTitlesOptionIsEnabled,
    FixVideoLinksOptionIsEnabled;
string
    NewFolderPath,
    OldFolderPath;
FILE[]
    FileArray;
FILE[ string ]
    FileByUuidSuffixMap;
FOLDER[]
    FolderArray;
FOLDER[ string ]
    FolderByNewFolderPathMap,
    FolderByOldFolderPathMap,
    FolderByUuidSuffixMap;

// -- FUNCTIONS

void PrintError(
    string message
    )
{
    writeln( "*** ERROR : ", message );
}

// ~~

void Abort(
    string message
    )
{
    PrintError( message );

    exit( -1 );
}

// ~~

void Abort(
    string message,
    Exception exception
    )
{
    PrintError( message );
    PrintError( exception.msg );

    exit( -1 );
}

// ~~

bool IsLinkLine(
    string line
    )
{
    return !matchFirst( line, LinkLineRegularExpression ).empty;
}

// ~~

bool HasUuidSuffix(
    string name
    )
{
    return !matchFirst( name, UuidSuffixedNameRegularExpression ).empty;
}

// ~~

string GetUuidSuffix(
    string name
    )
{
    return name[ $ - 33 .. $ ];
}

// ~~

string FixPathsSuffix(
    string name
    )
{
    return name[ 0 .. $ - 33 ].strip();
}

// ~~

string GetFolderPath(
    string[] folder_name_array
    )
{
    return folder_name_array.join( '/' ) ~ '/';
}

// ~~

string GetEncodedName(
    string name
    )
{
    string
        encoded_name;
    ubyte[]
        character_array;

    character_array = cast( ubyte[] )name;

    foreach ( character; character_array )
    {
        if ( character <= 32
             || character >= 128 )
        {
            encoded_name
                ~= "%"
                   ~ "0123456789ABCDEF"[ character >> 4 ]
                   ~ "0123456789ABCDEF"[ character & 15 ];
        }
        else
        {
            encoded_name ~= character.to!char();
        }
    }

    return encoded_name;
}

// ~~

string GetFullPath(
    string super_path,
    string sub_path
    )
{
    assert(
        super_path.endsWith( '/' )
        && sub_path.startsWith( '/' )
        );

    return super_path ~ sub_path[ 1 .. $ ];
}

// ~~

string GetPhysicalPath(
    string path
    )
{
    version( Windows )
    {
        return `\\?\` ~ path.absolutePath.replace( '/', '\\' ).replace( "\\.\\", "\\" );
    }

    return path;
}

// ~~

string GetLogicalPath(
    string path
    )
{
    return path.replace( '\\', '/' );
}

// ~~

string GetFolderPath(
    string file_path
    )
{
    long
        slash_character_index;

    if ( file_path.endsWith( '/' ) )
    {
        file_path = file_path[ 0 .. $ - 1 ];
    }

    slash_character_index = file_path.lastIndexOf( '/' );

    if ( slash_character_index >= 0 )
    {
        return file_path[ 0 .. slash_character_index + 1 ];
    }
    else
    {
        return "";
    }
}

// ~~

string GetFileLabel(
    string file_path
    )
{
    long
        slash_character_index;

    if ( file_path.endsWith( '/' ) )
    {
        file_path = file_path[ 0 .. $ - 1 ];
    }

    slash_character_index = file_path.lastIndexOf( '/' );

    if ( slash_character_index >= 0 )
    {
        return file_path[ slash_character_index + 1 .. $ ];
    }
    else
    {
        return file_path;
    }
}

// ~~

string GetFolderName(
    string folder_path
    )
{
    return folder_path.GetFileLabel();
}

// ~~

string GetFileName(
    string file_path
    )
{
    long
        dot_character_index;
    string
        file_label;

    file_label = file_path.GetFileLabel();

    dot_character_index = file_label.lastIndexOf( '.' );

    if ( dot_character_index >= 0 )
    {
        return file_label[ 0 .. dot_character_index ];
    }
    else
    {
        return file_label;
    }
}


// ~~

string GetFileExtension(
    string file_path
    )
{
    long
        dot_character_index;
    string
        file_label;

    file_label = file_path.GetFileLabel();

    dot_character_index = file_label.lastIndexOf( '.' );

    if ( dot_character_index >= 0 )
    {
        return file_label[ dot_character_index .. $ ];
    }
    else
    {
        return "";
    }
}

// ~~

void CreateFolder(
    string folder_path
    )
{
    try
    {
        if ( folder_path != ""
             && folder_path != "/"
             && !folder_path.exists() )
        {
            writeln( "Creating folder : ", folder_path );

            folder_path.GetPhysicalPath().mkdirRecurse();
        }
    }
    catch ( Exception exception )
    {
        Abort( "Can't create folder : " ~ folder_path, exception );
    }
}

// ~~

void CopyFile(
    string old_file_path,
    string new_file_path
    )
{
    CreateFolder( new_file_path.GetFolderPath() );

    writeln( "Copying file : ", old_file_path, " => ", new_file_path );

    try
    {
        old_file_path.GetPhysicalPath().copy(
            new_file_path.GetPhysicalPath()
            );
    }
    catch ( Exception exception )
    {
        Abort( "Can't copy file : " ~ old_file_path, exception );
    }
}

// ~~

string ReadText(
    string file_path
    )
{
    string
        file_text;

    writeln( "Reading file : ", file_path );

    try
    {
        file_text = file_path.GetPhysicalPath().readText();
    }
    catch ( Exception exception )
    {
        Abort( "Can't read file : " ~ file_path, exception );
    }

    return file_text;
}

// ~~

void WriteText(
    string file_path,
    string file_text
    )
{
    CreateFolder( file_path.GetFolderPath() );

    writeln( "Writing file : ", file_path );

    try
    {
        file_path.GetPhysicalPath().write( file_text );
    }
    catch ( Exception exception )
    {
        Abort( "Can't write file : " ~ file_path, exception );
    }
}

// ~~

FOLDER GetFolder(
    string[] folder_name_array
    )
{
    string
        folder_path;
    FOLDER*
        found_folder;

    folder_path = folder_name_array.GetFolderPath();
    found_folder = folder_path in FolderByOldFolderPathMap;

    if ( found_folder !is null )
    {
        return *found_folder;
    }
    else
    {
        return new FOLDER( folder_path, folder_name_array );
    }
}

// ~~

FOLDER[] GetFolderArray(
    string folder_path
    )
{
    long
        folder_name_count;
    string[]
        folder_name_array;
    FOLDER[]
        folder_array;

    folder_name_array = folder_path.split( '/' );

    for ( folder_name_count = 0;
          folder_name_count < folder_name_array.length;
          ++folder_name_count )
    {
        folder_array
            ~= GetFolder( folder_name_array[ 0 .. folder_name_count ] );
    }

    assert( folder_array[ $ - 1 ].GetOldPath() == folder_path );

    return folder_array;
}

// ~~

FILE GetFile(
    string file_path
    )
{
    return new FILE( file_path );
}

// ~~

void ScanFiles(
    )
{
    string
        physical_file_path,
        physical_folder_path;
    FILE
        file;

    writeln( "Scanning files : ", OldFolderPath );

    try
    {
        physical_folder_path = OldFolderPath.GetPhysicalPath();

        foreach ( folder_entry; physical_folder_path.dirEntries( SpanMode.depth ) )
        {
            if ( folder_entry.isFile()
                 && !folder_entry.isSymlink() )
            {
                physical_file_path = folder_entry.name();

                file = GetFile( "/" ~ physical_file_path[ physical_folder_path.length .. $ ].GetLogicalPath() );
            }
        }
    }
    catch ( Exception exception )
    {
        writeln( exception.msg );

        Abort( "Can't read folder : " ~ OldFolderPath.GetPhysicalPath() );
    }
}

// ~~

void RenameFiles(
    )
{
    writeln( "Renaming files : ", OldFolderPath );

    if ( FolderArray.length > 0 )
    {
        FolderArray[ 0 ].RenameFiles();
    }
}

// ~~

void CopyFiles(
    )
{
    writeln( "Copying files : ", NewFolderPath );

    if ( FolderArray.length > 0 )
    {
        FolderArray[ 0 ].CopyFiles();
    }
}

// ~~

void FixFiles(
    )
{
    writeln( "Fixing files : ", NewFolderPath );

    if ( FolderArray.length > 0 )
    {
        foreach ( folder; FolderArray )
        {
            FolderByNewFolderPathMap[ folder.GetNewPath() ] = folder;
        }

        FolderArray[ 0 ].FixFiles();
    }
}

// ~~

void main(
    string[] argument_array
    )
{
    string
        option;

    argument_array = argument_array[ 1 .. $ ];

    FixPathsOptionIsEnabled = false;
    FixNewlinesOptionIsEnabled = false;
    FixVideoLinksOptionIsEnabled = false;
    FixTitlesOptionIsEnabled = false;
    FixIndexesOptionIsEnabled = false;

    while ( argument_array.length >= 1
            && argument_array[ 0 ].startsWith( "--" ) )
    {
        option = argument_array[ 0 ];
        argument_array = argument_array[ 1 .. $ ];

        if ( option == "--fix-paths" )
        {
            FixPathsOptionIsEnabled = true;
        }
        else if ( option == "--fix-newlines" )
        {
            FixNewlinesOptionIsEnabled = true;
        }
        else if ( option == "--fix-video-links" )
        {
            FixVideoLinksOptionIsEnabled = true;
        }
        else if ( option == "--fix-titles" )
        {
            FixTitlesOptionIsEnabled = true;
        }
        else if ( option == "--fix-indexes" )
        {
            FixIndexesOptionIsEnabled = true;
        }
        else
        {
            Abort( "Invalid option : " ~ option );
        }
    }

    if ( ( argument_array.length == 1
           && !FixPathsOptionIsEnabled )
         || argument_array.length == 2 )
    {
        OldFolderPath = argument_array[ 0 ].GetLogicalPath();

        if ( argument_array.length == 2 )
        {
            NewFolderPath = argument_array[ 1 ].GetLogicalPath();
        }
        else
        {
            NewFolderPath = OldFolderPath;
        }

        if ( OldFolderPath.endsWith( '/' )
             && NewFolderPath.endsWith( '/' )
             && ( argument_array.length == 1
                  || ( !OldFolderPath.startsWith( NewFolderPath )
                       && !NewFolderPath.startsWith( OldFolderPath ) ) ) )
        {
            ScanFiles();

            if ( NewFolderPath != OldFolderPath )
            {
                if ( FixPathsOptionIsEnabled )
                {
                    RenameFiles();
                }

                CopyFiles();
            }

            FixFiles();

            return;
        }
    }

    writeln( "Usage :" );
    writeln( "    topaz [options] NOTION_EXPORT_FOLDER/ OBSIDIAN_VAULT_FOLDER/" );
    writeln( "    topaz [options] OBSIDIAN_VAULT_FOLDER/" );
    writeln( "Options :" );
    writeln( "    --fix-paths" );
    writeln( "    --fix-newlines" );
    writeln( "    --fix-video-links" );
    writeln( "    --fix-titles" );
    writeln( "    --fix-indexes" );
    writeln( "Examples :" );
    writeln( "    topaz --fix-paths --fix-newlines --fix-video-links --fix-titles --fix-indexes NOTION_EXPORT_FOLDER/ OBSIDIAN_VAULT_FOLDER/" );
    writeln( "    topaz --fix-newlines --fix-video-links --fix-titles --fix-indexes OBSIDIAN_VAULT_FOLDER/" );

    Abort( "Invalid arguments : " ~ argument_array.to!string() );
}
