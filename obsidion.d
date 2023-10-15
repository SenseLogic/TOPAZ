/*
    This file is part of the Obsidion distribution.

    https://github.com/senselogic/OBSIDION

    Copyright (C) 2020 Eric Pelzer (ecstatic.coder@gmail.com)

    Obsidion is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, version 3.

    Obsidion is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Obsidion.  If not, see <http://www.gnu.org/licenses/>.
*/

// -- IMPORTS

import core.stdc.stdlib : exit;
import std.conv : to;
import std.file : copy, dirEntries, exists, mkdirRecurse, readText, rename, SpanMode;
import std.path : absolutePath, baseName, dirName, globMatch;
import std.regex : matchFirst, regex;
import std.stdio : write, writeln, File;
import std.string : endsWith, indexOf, join, lastIndexOf, replace, split, startsWith, stripRight, toLower;

// -- TYPES

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
            NewName = OldName.RemoveUuidSuffix();
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

    void RenameFolders(
        )
    {
        bool
            new_name_exists;
        long
            number;
        string
            new_name;

        if ( IsRenamed )
        {
            if ( SuperFolder !is null )
            {
                number = 1;

                do
                {
                    if ( number == 1 )
                    {
                        new_name = NewName;
                    }
                    else
                    {
                        new_name = NewName ~ " (" ~ number.to!string() ~ ")";
                    }

                    new_name_exists = false;

                    foreach ( sibling_folder; SuperFolder.SubFolderArray )
                    {
                        new_name_exists
                            = ( sibling_folder != this
                                && sibling_folder.NewName == new_name );

                        if ( new_name_exists )
                        {
                            break;
                        }
                    }

                    ++number;
                }
                while ( new_name_exists );

                NewName = new_name;
            }
        }

        foreach ( sub_folder; SubFolderArray )
        {
            sub_folder.RenameFolders();
        }
    }

    // ~~

    void RenameFiles(
        )
    {
        bool
            new_label_exists;
        long
            number;
        string
            new_name,
            new_label;

        foreach ( file; FileArray )
        {
            if ( file.IsRenamed )
            {
                number = 1;

                do
                {
                    if ( number == 1 )
                    {
                        new_name = NewName;
                    }
                    else
                    {
                        new_name = NewName ~ " (" ~ number.to!string() ~ ")";
                    }

                    new_label = new_name ~ file.Extension;
                    new_label_exists = false;

                    foreach ( sibling_file; FileArray )
                    {
                        new_label_exists
                            = ( sibling_file != this
                                && sibling_file.GetNewLabel() == new_label );

                        if ( new_label_exists )
                        {
                            break;
                        }
                    }

                    ++number;
                }
                while ( new_label_exists );

                NewName = new_name;
            }
        }

        foreach ( sub_folder; SubFolderArray )
        {
            sub_folder.RenameFiles();
        }
    }

    // ~~

    void MoveFiles(
        )
    {
        foreach ( file; FileArray )
        {
            file.Move();
        }

        foreach ( sub_folder; SubFolderArray )
        {
            sub_folder.MoveFiles();
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

    void LinkFiles(
        )
    {
        foreach ( file; FileArray )
        {
            file.Link();
        }

        foreach ( sub_folder; SubFolderArray )
        {
            sub_folder.LinkFiles();
        }
    }
}

// ~~

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
        IsRenamed,
        IsLinked;

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

        IsRenamed
            = ( ( Extension == ".md"
                  || Extension == ".csv" )
                && OldName.HasUuidSuffix() );

        IsLinked = ( Extension == ".md" );

        if ( IsRenamed )
        {
            NewName = OldName.RemoveUuidSuffix();
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

    void Dump(
        )
    {
        writeln( GetOldPath(), "\n", GetNewPath(), "\n" );
    }

    // -- OPERATIONS

    void Move(
        )
    {
        MoveFile(
            GetFullPath( .OldFolderPath, GetOldPath() ),
            GetFullPath( .NewFolderPath, GetNewPath() )
            );
    }

    // ~~

    void Copy(
        )
    {
        CopyFile(
            GetFullPath( .OldFolderPath, GetOldPath() ),
            GetFullPath( .NewFolderPath, GetNewPath() )
            );
    }

    // ~~

    void Link(
        )
    {
        if ( IsLinked )
        {
        }
    }
}

// -- CONSTANTS

auto
    UuidSuffixedNameRegularExpression = regex( "^.+ [0-9a-f]{32}$" );

// -- VARIABLES

bool
    MoveOptionIsEnabled;
string
    OldFolderPath,
    NewFolderPath;
FILE[]
    FileArray;
FOLDER[]
    FolderArray;
FOLDER[ string ]
    FolderByOldFolderPathMap;

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

bool HasUuidSuffix(
    string name
    )
{
    return !matchFirst( name, UuidSuffixedNameRegularExpression ).empty;
}

// ~~

string RemoveUuidSuffix(
    string name
    )
{
    return name[ 0 .. $ - 33 ];
}

// ~~

string GetFolderPath(
    string[] folder_name_array
    )
{
    return folder_name_array.join( '/' ) ~ '/';
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
        if ( path.length > 260 )
        {
            return `\\?\` ~ path.absolutePath;
        }
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
        return file_label;
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

void MoveFile(
    string old_file_path,
    string new_file_path
    )
{
    CreateFolder( new_file_path.GetFolderPath() );

    writeln( "Moving file : ", old_file_path, " => ", new_file_path );

    try
    {
        old_file_path.GetPhysicalPath().rename(
            new_file_path.GetPhysicalPath()
            );
    }
    catch ( Exception exception )
    {
        Abort( "Can't move file : " ~ old_file_path, exception );
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
    writeln( "Reading file : ", file_path );

    return new FILE( file_path );
}

// ~~

void ScanFiles(
    )
{
    FILE
        file;

    writeln( "Scanning files : ", OldFolderPath );

    try
    {
        foreach ( file_path; OldFolderPath.dirEntries( SpanMode.depth ) )
        {
            if ( file_path.isFile()
                 && !file_path.isSymlink() )
            {
                file = GetFile( "/" ~ file_path.name().GetLogicalPath()[ OldFolderPath.length .. $ ] );
            }
        }
    }
    catch ( Exception exception )
    {
        writeln( exception.msg );

        Abort( "Can't read folder : " ~ OldFolderPath );
    }
}

// ~~

void RenameFolders(
    )
{
    writeln( "Renaming folders : ", OldFolderPath );

    if ( FolderArray.length > 0 )
    {
        FolderArray[ 0 ].RenameFolders();
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

void MoveFiles(
    )
{
    writeln( "Moving files : ", NewFolderPath );

    if ( FolderArray.length > 0 )
    {
        FolderArray[ 0 ].MoveFiles();
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

void LinkFiles(
    )
{
    writeln( "Linking files : ", NewFolderPath );

    if ( FolderArray.length > 0 )
    {
        FolderArray[ 0 ].LinkFiles();
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

    MoveOptionIsEnabled = false;

    while ( argument_array.length >= 1
            && argument_array[ 0 ].startsWith( "--" ) )
    {
        option = argument_array[ 0 ];
        argument_array = argument_array[ 1 .. $ ];

        if ( option == "--move" )
        {
            MoveOptionIsEnabled = true;
        }
        else
        {
            Abort( "Invalid option : " ~ option );
        }
    }

    if ( argument_array.length == 2 )
    {
        OldFolderPath = argument_array[ 0 ].GetLogicalPath();
        NewFolderPath = argument_array[ 1 ].GetLogicalPath();

        if ( OldFolderPath.endsWith( '/' )
             && NewFolderPath.endsWith( '/' )
             && !OldFolderPath.startsWith( NewFolderPath )
             && !NewFolderPath.startsWith( OldFolderPath ) )
        {
            ScanFiles();
            RenameFolders();
            RenameFiles();

            if ( MoveOptionIsEnabled )
            {
                MoveFiles();
            }
            else
            {
                CopyFiles();
            }

            LinkFiles();

            return;
        }
    }

    writeln( "Usage :" );
    writeln( "    obsidion [options] OLD_FOLDER/ NEW_FOLDER/" );
    writeln( "Options :" );
    writeln( "    --move" );
    writeln( "Examples :" );
    writeln( "    obsidion NOTION_EXPORT_FOLDER/ OBSIDIAN_VAULT_FOLDER/" );
    writeln( "    obsidion --move NOTION_EXPORT_FOLDER/ OBSIDIAN_VAULT_FOLDER/" );

    Abort( "Invalid arguments : " ~ argument_array.to!string() );
}
