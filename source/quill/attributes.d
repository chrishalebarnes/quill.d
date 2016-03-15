/**
    Copyright: © 2015 Chris Barnes
    License: The MIT License, see license file
    Authors: Chris Barnes

    Examples:
        ---
        class Model
        {
            int id;
            @bind("columnName") string name;
        }
        ---

        ---
        class Model
        {
            int id;
            @omit string name;
        }
        ---

    See_also:
        quill.mapper
*/
module quill.attributes;

/**
    Specifies a column name in a user defined attribute on a property.
*/
struct bind
{
    public string bind;
}

/**
    The property to which this attribute is attached will not be mapped into the result
*/
enum omit = "omit";
