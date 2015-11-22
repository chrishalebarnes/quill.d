/**
    Copyright: © 2015 Chris Barnes
    License: The MIT License, see license file
    Authors: Chris Barnes
*/
module quill.variant_mapper;

import ddbc.all;
import std.datetime;
import std.variant;
import quill.mapper_base;

/**
    Maps Variant parameters to a PreparedStatement

    See_also:
        quill.database
*/
class VariantMapper : MapperBase
{
    this(PreparedStatement statement)
    {
        super(statement);
    }

    /**
        Maps an array of Variants into a PreparedStatement

        Params:
            parameters = an array of variants where the index matches the index of the parameter
    */
    void map(Variant[] parameters)
    {
        foreach(int i, parameter;parameters)
        {
            this.mapType(i + 1, parameter);
        }
    }

    private:
        /**
            Sets a parameter on the PreparedStatement if it is supported
        */
        void mapType(int parameterIndex, Variant value)
        {
            if(value.convertsTo!(float))
            {
                this.statement.setFloat(parameterIndex, value.get!(float));
            }
            else if(value.convertsTo!(double))
            {
                this.statement.setDouble(parameterIndex, value.get!(double));
            }
            else if(value.convertsTo!(bool))
            {
                this.statement.setBoolean(parameterIndex, value.get!(bool));
            }
            else if(value.convertsTo!(long))
            {
                this.statement.setLong(parameterIndex, value.get!(long));
            }
            else if(value.convertsTo!(ulong))
            {
                this.statement.setUlong(parameterIndex, value.get!(ulong));
            }
            else if(value.convertsTo!(int))
            {
                this.statement.setInt(parameterIndex, value.get!(int));
            }
            else if(value.convertsTo!(uint))
            {
                this.statement.setUint(parameterIndex, value.get!(uint));
            }
            else if(value.convertsTo!(short))
            {
                this.statement.setShort(parameterIndex, value.get!(short));
            }
            else if(value.convertsTo!(ushort))
            {
                this.statement.setUshort(parameterIndex, value.get!(ushort));
            }
            else if(value.convertsTo!(byte))
            {
                this.statement.setByte(parameterIndex, value.get!(byte));
            }
            else if(value.convertsTo!(ubyte))
            {
                this.statement.setUbyte(parameterIndex, value.get!(ubyte));
            }
            else if(value.convertsTo!(byte[]))
            {
                this.statement.setBytes(parameterIndex, value.get!(byte[]));
            }
            else if(value.convertsTo!(ubyte[]))
            {
                this.statement.setUbytes(parameterIndex, value.get!(ubyte[]));
            }
            else if(value.convertsTo!(string))
            {
                this.statement.setString(parameterIndex, value.get!(string));
            }
            else if(value.convertsTo!(DateTime))
            {
                this.statement.setDateTime(parameterIndex, value.get!(DateTime));
            }
            else
            {
                this.statement.setNull(parameterIndex);
            }
        }
}
