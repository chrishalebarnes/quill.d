/**
    Copyright: © 2015 Chris Barnes
    License: The MIT License, see license file
    Authors: Chris Barnes

    See_also:
        quill.mapper
        quill.variant_mapper
*/
module quill.mapper_base;

import ddbc.all;

/**
    Base class for Mapper and VariantMapper
*/
abstract class MapperBase
{
    this(ResultSet resultSet)
    {
        this.resultSet = resultSet;
    }

    this(PreparedStatement statement)
    {
        this.statement = statement;
    }

    protected:
        ResultSet resultSet;
        PreparedStatement statement;

        /**
            Finds the index of a column.

            Params:
                name = name of the column to find
            Returns:
                index of the column
        */
        int findColumn(string name)
        {
            ResultSetMetaData rsmd = this.resultSet.getMetaData();
            int count = rsmd.getColumnCount();
            for(int i=1; i < count+1; i++)
            {
                if(rsmd.getColumnName(i) == name)
                {
                    return i;
                }
            }
            return 0;
        }
}
