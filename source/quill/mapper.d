/**
    Copyright: © 2015 Chris Barnes
    License: The MIT License, see license file
    Authors: Chris Barnes

    See_also:
        quill.database
*/
module quill.mapper;

import ddbc.all;
import std.algorithm;
import std.array;
import std.conv;
import std.datetime;
import std.traits;
import std.variant;
import quill.mapper_base;

/**
    Maps parameters, and results to a class specified by T.
*/
class Mapper(T) : MapperBase
{
    this(ResultSet resultSet)
    {
        super(resultSet);
    }

    this(PreparedStatement statement)
    {
        super(statement);
    }

    string getBindName(T, string property)(T model)
    {
        auto attributes = __traits(getAttributes, __traits(getMember, model, property));

        foreach(index, attribute; attributes)
        {
            static if(is(typeof(attribute) == quill.attributes.bind))
            {
                return attribute.bind;
            }
        }
        return "";
    }

    /**
        Maps each property of T to a column in a ResultSet.
        If T is a class, it will new it up and map all of the public fields.
        If T is a primitive type it will assume the result of the query boils down to a single value and returns that.
        Returns:
            An instance of T or a single primitive value.
    */
    T map()
    {
        static if(isSupportedType!(T)())
        {
            return this.resultSet.getRow() > 0 ? this.mapType!(T)(1) : T.init;
        }
        else
        {
            T model = new T();
            if(this.resultSet.getRow() > 0)
            {
                foreach(int i, property;__traits(allMembers, T))
                {
                    int columnIndex;
                    static if(isPublic!(T, property))
                    {
                        //Note: must check isPublic first since isIgnored accesses the property
                        static if(!isIgnored!(T, property)())
                        {
                            string bindName = getBindName!(T, property)(model);
                            if(bindName != "")
                            {
                                columnIndex = this.findColumn(bindName);
                            }
                            if(columnIndex == 0)
                            {
                                columnIndex = this.findColumn(property);
                            }
                            if(columnIndex != 0) {
                                static if(T.tupleof.length > i)
                                {
                                    __traits(getMember, model, property) = this.mapType!(typeof(T.tupleof[i]))(columnIndex);
                                }
                            }
                        }
                    }
                }
                return model;
            }
            else
            {
                return null;
            }
        }
    }

    /**
        Maps a class into a PreparedStatement

        Params:
            model = an instance of T with fields that match the parmeter names or provide a bind user defined attribute
            map = a string array where the index is the parameter index and the string is the parameter name
    */
    void map(T)(T model, string[] map)
    {
        foreach(int i, property;__traits(allMembers, T))
        {
            int parameterIndex;
            static if(isPublic!(T, property))
            {
                //Note: must check isPublic first since isIgnored accesses the property
                static if(!isIgnored!(T, property)())
                {
                    auto attributes = __traits(getAttributes, __traits(getMember, model, property));
                    parameterIndex = to!(int)(countUntil(map, property)) + 1;

                    string bindName = getBindName!(T, property)(model);
                    if(bindName != "")
                    {
                        parameterIndex = to!(int)(countUntil(map, bindName)) + 1;
                    }

                    if(parameterIndex > 0) {
                        static if(T.tupleof.length > i)
                        {
                            this.mapType!(typeof(T.tupleof[i]))(parameterIndex, __traits(getMember, model, property));
                        }
                    }
                }
            }
        }
    }

    /**
        Maps an array of models where the ResultSet is expected to have multiple rows
    */
    T[] mapArray()
    {
        auto appender = appender!(T[])();
        while (this.resultSet.next())
        {
            appender.put(this.map());
        }
        return appender.data;
    }

    /**
        Maps a single T where the ResultSet is expected to have only one row.
    */
    T mapOne()
    {
        this.resultSet.next();
        return this.map();
    }

    private:
        /**
            Sets a parameter on the PreparedStatement if it is supported
        */
        void mapType(T)(int parameterIndex, T value)
        {
            static if(is(T == float))
            {
                this.statement.setFloat(parameterIndex, value);
            }
            else static if(is(T == double))
            {
                this.statement.setDouble(parameterIndex, value);
            }
            else static if(is(T == bool))
            {
                this.statement.setBoolean(parameterIndex, value);
            }
            else static if(is(T == long))
            {
                this.statement.setLong(parameterIndex, value);
            }
            else static if(is(T == ulong))
            {
                this.statement.setUlong(parameterIndex, value);
            }
            else static if(is(T == int))
            {
                this.statement.setInt(parameterIndex, value);
            }
            else static if(is(T == uint))
            {
                this.statement.setUint(parameterIndex, value);
            }
            else static if(is(T == short))
            {
                this.statement.setShort(parameterIndex, value);
            }
            else static if(is(T == ushort))
            {
                this.statement.setUshort(parameterIndex, value);
            }
            else static if(is(T == byte))
            {
                this.statement.setByte(parameterIndex, value);
            }
            else static if(is(T == ubyte))
            {
                this.statement.setUbyte(parameterIndex, value);
            }
            else static if(is(T == byte[]))
            {
                this.statement.setBytes(parameterIndex, value);
            }
            else static if(is(T == ubyte[]))
            {
                this.statement.setUbytes(parameterIndex, value);
            }
            else static if(is(T == string))
            {
                this.statement.setString(parameterIndex, value);
            }
            else static if(is(T == DateTime))
            {
                this.statement.setDateTime(parameterIndex, value);
            }
            else
            {
                this.statement.setNull(parameterIndex);
            }
        }

        /**
            Gets a value out of the current row if it is supported.
        */
        T mapType(T)(int columnIndex)
        {
            static if(is(T == float))
            {
                 return this.resultSet.getFloat(columnIndex);
            }
            else static if(is(T == double))
            {
                return this.resultSet.getDouble(columnIndex);
            }
            else static if(is(T == bool))
            {
                return this.resultSet.getBoolean(columnIndex);
            }
            else static if(is(T == long))
            {
                return this.resultSet.getLong(columnIndex);
            }
            else static if(is(T == ulong))
            {
                return this.resultSet.getUlong(columnIndex);
            }
            else static if(is(T == int))
            {
                return this.resultSet.getInt(columnIndex);
            }
            else static if(is(T == uint))
            {
                return this.resultSet.getUint(columnIndex);
            }
            else static if(is(T == short))
            {
                return this.resultSet.getShort(columnIndex);
            }
            else static if(is(T == ushort))
            {
                return this.resultSet.getUshort(columnIndex);
            }
            else static if(is(T == byte))
            {
                return this.resultSet.getByte(columnIndex);
            }
            else static if(is(T == ubyte))
            {
                return this.resultSet.getUbyte(columnIndex);
            }
            else static if(is(T == byte[]))
            {
                return this.resultSet.getBytes(columnIndex);
            }
            else static if(is(T == ubyte[]))
            {
                return this.resultSet.getUbytes(columnIndex);
            }
            else static if(is(T == string))
            {
                return this.resultSet.getString(columnIndex);
            }
            else static if(is(T == DateTime))
            {
                return this.resultSet.getDateTime(columnIndex);
            }
            else
            {
                return null;
            }
        }
}

/**
    Checks if T is one of the supported primitive types
*/
bool isSupportedType(T)()
{
    return is(T == float)   || is(T == double) || is(T == bool)     || is(T == long)   || is(T == ulong) || is(T == int)    ||
           is(T == uint)    || is(T == short)  || is(T == ushort)   || is(T == byte)   || is(T == ubyte) || is(T == byte[]) ||
           is(T == ubyte[]) || is(T == string) || is(T == DateTime);

}

/**
    Checks if the property of T has the @omit attribute
*/
bool isIgnored(T, string property)()
{
    auto attributes = __traits(getAttributes, __traits(getMember, T, property));
    foreach(index, attribute; attributes)
    {
        if(attribute.to!string == quill.attributes.omit)
        {
            return true;
        }
    }
    return false;
}

/**
    Checks if the property of T is public
*/
bool isPublic(T, string property)()
{
    static if(__traits(getProtection, __traits(getMember, T, property)) == "public")
    {
        return true;
    }
    else
    {
        return false;
    }
}
