/**
    Copyright: © 2015 Chris Barnes
    License: The MIT License, see license file
    Authors: Chris Barnes

    Examples:
        ---
        class Model
        {
            int id;
            @(bind("columnName")) string name;
        }
        ---

    See_also:
        quill.mapper
*/
module quill.bind;

/**
    Specifies a column name in a user defined attribute on a property.
*/
struct bind
{
    public string bind;
}
