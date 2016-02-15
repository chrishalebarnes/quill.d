/**
    Copyright: © 2015 Chris Barnes
    License: The MIT License, see license file
    Authors: Chris Barnes

    See_also:
        quill.database_type;
        quill.mapper;
        quill.variant_mapper;
*/
module quill.database;

import ddbc.all;
import std.array;
import std.regex;
import std.string;
import std.traits;
import std.variant;
import quill.mapper;
import quill.variant_mapper;

/**
     Represents a database that can execute various kinds of SQL Queries
 */
class Database
{
    /**
        Creates a new Database given an existing DataSource
    */
    this(DataSource datasource)
    {
        this.datasource = datasource;
    }

    version(USE_SQLITE)
    {
        /**
            Creates a new SQLite Database
        */
        this(string path)
        {
            string[string] params;
            SQLITEDriver sqliteDriver = new SQLITEDriver();
            this.datasource = new ConnectionPoolDataSourceImpl(sqliteDriver, path, params);
        }
    }

    version(USE_PGSQL)
    {
        /**
            Creates a new PostgreSQL Database.
        */
        this(string host, ushort port, string name, string username, string password, bool ssl)
        {
            string[string] params;
            PGSQLDriver driver = new PGSQLDriver();
            string url = PGSQLDriver.generateUrl(host, port, name);
            params["user"] = username;
            params["password"] = password;
            params["ssl"] = ssl ? "true" : "false";
            this.datasource = new ConnectionPoolDataSourceImpl(driver, url, params);
        }
    }

    version(USE_MYSQL)
    {
        /**
            Creates a new MySQL Database.
        */
        this(string host, ushort port, string name, string username, string password)
        {
            string[string] params;
            MySQLDriver driver = new MySQLDriver();
            string url = MySQLDriver.generateUrl(host, port, name);
            params = MySQLDriver.setUserAndPassword(username, password);
            this.datasource = new ConnectionPoolDataSourceImpl(driver, url, params);
        }
    }

    /**
        Import a SQL string from a file
        Params:
            path = path to a sql file that will be imported
        Returns:
            a string of the SQL in the file
    */
    string sql(string path)()
    {
        return import(path);
    }

    /* No Parameters */

    /**
        Execute a SQL statment with no parameters and no return
        Params:
            sql = SQL statement to execute
        Examples:
            ---
            database.execute("insert into models values('value');")
            ---
    */
    void execute(string sql)
    {
        auto connection = this.datasource.getConnection();
        scope(exit) connection.close();
        auto statement = connection.createStatement();
        scope(exit) statement.close();
        statement.executeUpdate(sql);
    }

    /**
        Execute a SQL statment from a file with no parameters and no return
        Params:
            path = path to SQL file
        Examples:
            ---
            database.execute!("queries/statement.sql")();
            ---
    */
    void execute(string path)()
    {
        this.execute(this.sql!(path)());
    }

    /**
        Execute a SQL statement that returns a single row
        Params:
            T = type to map columns to
            sql = SQL statement to execute
        Returns:
            new instance of T with fields mapped to columns
        Examples:
            ---
            audo model = database.single!(Model)("select * from models limit 1;");
            ---
    */
    T single(T)(string sql)
    {
        auto connection = this.datasource.getConnection();
        scope(exit) connection.close();

        auto statement = connection.createStatement();
        scope(exit) statement.close();

        ResultSet resultSet = statement.executeQuery(sql);

        auto mapper = new Mapper!(T)(resultSet);
        return mapper.mapOne();
    }

    /**
        Execute a SQL statment from a file that returns a single row
        Params:
            T = type to map columns to
            path = path to SQL file
        Returns:
            new instance of T with fields mapped to columns
        Examples:
            ---
            audo model = database.single!(Model, "queries/statement.sql")();
            ---
    */
    T single(T, string path)()
    {
        return this.single!(T)(this.sql!(path));
    }

    /**
        Execute a SQL statment that returns multiple rows
        Params:
            T = type to map columns to
            sql = SQL statement to execute
        Returns:
            new array of T with the fields for each T mapped to columns
        Examples:
            ---
            auto models = database.list!(Model)("select * from models;");
            ---
    */
    T[] list(T)(string sql)
    {
        auto connection = this.datasource.getConnection();
        scope(exit) connection.close();

        auto statement = connection.createStatement();
        scope(exit) statement.close();

        ResultSet resultSet = statement.executeQuery(sql);

        auto mapper = new Mapper!(T)(resultSet);
        return mapper.mapArray();
    }

    /**
        Execute a SQL statement from a file that returns multiple rows
        Params:
            T = type to map columns to
            path = path to SQL file
        Returns
            new array of T with the fields for each T mapped to columns
        Examples:
            ---
            auto models = database.list!(Model, "queries/statement.sql")();
            ---
    */
    T[] list(T, string path)()
    {
        return this.list!(T)(this.sql!(path)());
    }

    /* Variant Parameters */

    /**
        Execute a SQL statment that takes a single Variant parameter
        Params:
            sql = SQL statement to execute
            parameter = a single Variant parameter
        Examples:
            ---
            database.execute("insert into models(name) values(?);", Variant("name"));
            ---
    */
    void execute(string sql, Variant parameter)
    {
        this.execute(sql, [parameter]);
    }

    /**
        Execute a SQL statement from a file that takes a single Variant parameter
        Params:
            path = path to SQL file
            parameter = a single Variant parameter
        Examples:
            ---
            database.execute!("queries/statement.sql")(Variant("value"));
            ---
    */
    void execute(string path)(Variant parameter)
    {
        this.execute(this.sql!(path)(), parameter);
    }

    /**
        Execute a SQL statement that takes many Variant parameters
        Params:
            sql = SQL statement to execute
            parameters = many ordered Variant parameters
        Examples:
            ---
            database.execute("insert into models(name, description) values(?, ?)", variantArray("value one", "value two"));
            ---
    */
    void execute(string sql, Variant[] parameters)
    {
        auto connection = this.datasource.getConnection();
        scope(exit) connection.close();

        auto statement = connection.prepareStatement(sql);
        scope(exit) statement.close();

        auto mapper = new VariantMapper(statement);
        mapper.map(parameters);
        statement.executeUpdate();
    }

    /**
        Execute a SQL statement from a file that takes many Variant parameters
        Params:
            path = path to SQL file
            parameters = many ordered Variant parameters
        Examples:
            ---
            database.execute!("queries/statement.sql")(variantArray("value one", "value two"));
            ---
    */
    void execute(string path)(Variant[] parameters)
    {
        this.execute(this.sql!(path)(), parameters);
    }

    /**
        Execute a SQL statement that takes a Variant parameter and returns a single row
        Params:
            T = type to map columns to
            sql = SQL statement to execute
            parameter = single Variant parameter
        Returns:
            new instance of T with fields mapped to columns
        Examples:
            ---
            auto model = database.single!(Model)("select * from models where id = ?;", Variant(4));
            ---
    */
    T single(T)(string sql, Variant parameter)
    {
        return this.single!(T)(sql, [parameter]);
    }

    /**
        Execute a SQL statement from a file that takes a Variant parameter and returns a single row
        Params:
            T = type to map columns to
            path = path to SQL file
            parameter = single Variant parameter
        Returns:
            new instance of T with fields mapped to columns
        Examples:
            ---
            auto model = database.single!(Model, "queries/statement.sql")(Variant(4));
            ---
    */
    T single(T, string path)(Variant parameter)
    {
        return this.single!(T)(this.sql!(path)(), parameter);
    }

    /**
        Execute a SQL statement that takes many Variant parameters and returns a single row
        Params:
            T = type to map columns to
            sql = SQL statement to execute
            parameters = many ordered Variant parameters
        Returns:
            new instance of T with fields mapped to columns
        Examples:
            ---
            auto model = database.single!(Model)("select * from models where name = ? and description = ?", variantArray("value one", "value two"));
            ---
    */
    T single(T)(string sql, Variant[] parameters)
    {
        auto connection = this.datasource.getConnection();
        scope(exit) connection.close();

        auto statement = connection.prepareStatement(sql);
        scope(exit) statement.close();

        auto parameterMapper = new VariantMapper(statement);
        parameterMapper.map(parameters);

        ResultSet resultSet = statement.executeQuery();

        auto resultMapper = new Mapper!(T)(resultSet);
        return resultMapper.mapOne();
    }

    /**
        Execute a SQL statement from a file that takes many Variant parameters and returns a single row
        Params:
            T = type to map columns to
            path = path to SQL file
            parameters = many ordered Variant parameters
        Returns:
            new instance of T with fields mapped to columns
        Examples:
            ---
            auto model = database.single!(Model, "queries/statement.sql")(variantArray("value one", "value two"));
            ---
    */
    T single(T, string path)(Variant[] parameters)
    {
        return this.single!(T)(this.sql!(path)(), parameters);
    }

    /**
        Execute a SQL statement that takes a single Variant parameter and returns many rows
        Params:
            T = type to map columns to
            sql = SQL statement to execute
            parameter = single Variant parameter
        Returns:
            new array of T with the fields for each T mapped to columns
        Examples:
            ---
            auto models = database.list!(Model)("select * from models where name = ?;", Variant("value"))
            ---
    */
    T[] list(T)(string sql, Variant parameter)
    {
        return this.list!(T)(sql, [parameter]);
    }

    /**
        Execute a SQL statement from a file that takes a single Variant parameter and returns many rows
        Params:
            T = type to map columns to
            path = path to SQL file
            parameter = single Variant parameter
        Returns:
            new array of T with the fields for each T mapped to columns
        Examples:
            ---
            auto models = database.list!(Model, "queries/statement.sql")(Variant("value"));
            ---
    */
    T[] list(T, string path)(Variant parameter)
    {
        return this.list!(T)(this.sql!(path)(), parameter);
    }

    /**
        Execute a SQL statement that takes many Variant parameters and returns many rows
        Params:
            T = type to map columns to
            sql = SQL statement to execute
            parameters = many ordered Variant parameters
        Returns:
            new array of T with the fields for each T mapped to columns
        Examples:
            ---
            auto models = database.list!(Model)("select * from models where name = ? and description = ?;", variantArray("value one", "value two"));
            ---
    */
    T[] list(T)(string sql, Variant[] parameters)
    {
        auto connection = this.datasource.getConnection();
        scope(exit) connection.close();

        auto statement = connection.prepareStatement(sql);
        scope(exit) statement.close();

        auto parameterMapper = new VariantMapper(statement);
        parameterMapper.map(parameters);

        ResultSet resultSet = statement.executeQuery();

        auto resultMapper = new Mapper!(T)(resultSet);
        return resultMapper.mapArray();
    }

    /**
        Execute a SQL statement from a file that takes many Variant parameters and returns many rows
        Params:
            T = type to map columns to
            path = path to SQL file
            parameters = many ordered Variant parameters
        Returns:
            new array of T with the fields for each T mapped to columns
        Examples:
            ---
            auto models = database.list!(Model, "queries/statement.sql")(variantArray("value one", "value two"));
            ---
    */
    T[] list(T, string path)(Variant[] parameters)
    {
        return this.list!(T)(this.sql!(path)(), parameters);
    }

    /* Model Parameters */

    /**
        Execute a SQL statement that takes a model parameter
        Params:
            T = type to map parameters to
            sql = SQL statement to execute
            model = model to map parameters to
        Examples:
            ---
            class Model
            {
                int id;
                @(bind("name")) string name;
            }
            auto model = new Model();
            model.name = "value";
            database.execute!(Model)("insert into models(name) values(?(name));", model);
            ---
    */
    void execute(T)(string sql, T model)
    {
        string[] map = this.parseBindValues!(T)(sql, model);
        auto connection = this.datasource.getConnection();
        scope(exit) connection.close();

        auto statement = connection.prepareStatement(sql);
        scope(exit) statement.close();

        auto mapper = new Mapper!(T)(statement);
        mapper.map(model, map);
        statement.executeUpdate();
    }

    /**
        Execute a SQL statement from a file that takes a model parameter
        Params:
            T = type to map parameters to
            path = path to SQL file
            model = model to map parameters to
        Examples:
            ---
            class Model
            {
                int id;
                @(bind("name")) string name;
            }
            auto model = new Model();
            model.name = "value";
            database.execute!(Model, "queries/statement.sql", model);
            ---
    */
    void execute(T, string path)(T model)
    {
        this.execute!(T)(this.sql!(path)(), model);
    }

    /**
        Execute a SQL statement that takes a model parameter and returns a single row
        Params:
            T = type to map parameters and columns to
            sql = SQL statement to execute
            model = model to map parameters and columns to
        Returns:
            new instance of T with fields mapped to columns
        Examples:
            ---
            class Model
            {
                int id;
                @(bind("name")) string name;
            }
            auto model = new Model();
            model.id = 4;
            auto fetchedModel = database.single!("select * from models where id = ?;", model);
            ---
    */
    T single(T)(string sql, T model)
    {
        string[] map = this.parseBindValues!(T)(sql, model);
        auto connection = this.datasource.getConnection();
        scope(exit) connection.close();

        auto statement = connection.prepareStatement(sql);
        scope(exit) statement.close();

        auto parameterMapper = new Mapper!(T)(statement);
        parameterMapper.map(model, map);

        ResultSet resultSet = statement.executeQuery();

        auto resultMapper = new Mapper!(T)(resultSet);
        return resultMapper.mapOne();
    }

    /**
        Execute a SQL statement from a file that takes a model parameter and returns a single row
        Params:
            T = type to map parameters and columns to
            path = path to SQL file
            model = model to map parameters and columns to
        Returns:
            new instance of T with fields mapped to columns
        Examples:
            ---
            class Model
            {
                int id;
                @(bind("name")) string name;
            }
            auto model = new Model();
            model.id = 4;
            auto model = database.single!(Model, "queries/statement.sql", model);
            ---
    */
    T single(T, string path)(T model)
    {
        return this.single!(T)(this.sql!(path)(), model);
    }

    /**
        Execute a SQL statement that takes a model parameter and returns many rows
        Params:
            T = type to map parameters and columns to
            sql = SQL statement to execute
            model = model to map parameters and columns to
        Returns:
            new array of T with the fields for each T mapped to columns
        Examples:
            ---
            class Model
            {
                int id;
                @(bind("name")) string name;
            }
            auto model = new Model();
            model.name = "value";
            auto models = database.list!(Model)("select * from models where name = ?(name);", model);
            ---
    */
    T[] list(T)(string sql, T model)
    {
        string[] map = this.parseBindValues!(T)(sql, model);
        auto connection = this.datasource.getConnection();
        scope(exit) connection.close();

        auto statement = connection.prepareStatement(sql);
        scope(exit) statement.close();

        auto parameterMapper = new Mapper!(T)(statement);
        parameterMapper.map(model, map);

        ResultSet resultSet = statement.executeQuery();

        auto resultMapper = new Mapper!(T)(resultSet);
        return resultMapper.mapArray();
    }

    /**
        Execute a SQL statement from a file that takes a model parameter and returns many rows
        Params:
            T = type to map parameters and columns to
            path = path to SQL file
            model = model to map parameters and columns to
        Returns:
            new array of T with the fields for each T mapped to columns
        Examples:
            ---
            class Model
            {
                int id;
                @(bind("name")) string name;
            }
            auto model = new Model();
            model.name = "value";
            auto models = database.list!(Model, "queries/statement.sql")(model);
            ---
    */
    T[] list(T, string path)(T model)
    {
        return this.list!(T)(this.sql!(path)(), model);
    }

    private:
        DataSource datasource;

        /**
            Replace ?(parameter_name) with ? and return an array indicating the order of the named parameters
            Params:
                T = type of model to map parameters to
                sql = raw SQL string
                model = model to be mapped into the PreparedStatement
            Returns:
                An array where the index matches the parameter index and the value matches the name of the parameter
        */
        string[] parseBindValues(T)(ref string sql, T model)
        {
            auto appender = appender!(string[])();

            foreach(match; matchAll(sql, regex(r"\?\(([^)]+)\)")))
            {
                appender.put(chompPrefix(chop(match.hit), "?("));
                sql = sql.replace(match.hit, "?");
            }
            return appender.data;
        }
}

version(unittest)
{
    import quill.bind;
    import std.datetime;
    import std.conv;

    Database createSqliteConnection()
    {
        string[string] sqlLiteParams;
        SQLITEDriver sqliteDriver = new SQLITEDriver();
        DataSource sqlite3DataSource = new ConnectionPoolDataSourceImpl(sqliteDriver, "test.sqlite3", sqlLiteParams);
        DataSource datasource = new ConnectionPoolDataSourceImpl(sqliteDriver, "test.sqlite3", sqlLiteParams);

        auto db = new Database(datasource);
        string sql = "
            create table if not exists models(
                id integer primary key autoincrement not null,
                name text not null,
                title text
            );
        ";
        db.execute(sql);
        return db;
    }

    Database createPostgresConnection()
    {
        auto db = new Database("127.0.0.1", to!(ushort)(54320), "testdb", "admin", "password", true);
        string sql = "
            create table if not exists models(
                id serial primary key,
                name varchar(100),
                title varchar(100)
            );
        ";
        db.execute(sql);
        return db;
    }

    Database createMysqlConnection()
    {
        auto db = new Database("127.0.0.1", to!(ushort)(33060), "testdb", "admin", "password");

        string sql = "
            create table if not exists models(
                id mediumint not null auto_increment primary key,
                name varchar(100),
                title varchar(100)
            );
        ";
        db.execute(sql);
        return db;
    }

    void teardown(Database[] dbs)
    {
        foreach(db; dbs)
        {
            db.execute("drop table if exists models;");
        }
    }

    class Model
    {
        @(bind("id")) int id;
        @(bind("name")) string name;
        @(bind("title")) string title;

        this(string name)
        {
            this.name = name;
        }

        this() { }
    }

    Database[] all()
    {
        return [createSqliteConnection(), createPostgresConnection(), createMysqlConnection()];
    }
}

/* No Parameters */

// T single(T)(string);
unittest
{
    auto dbs = all();
    scope(exit) teardown(dbs);
    foreach(db; dbs)
    {
        db.execute!("none/insert.sql")();
        Model model = db.single!(Model, "none/single.sql")();
        assert(model.name == "Some Name");
    }
}

// T[] list(T)(string);
unittest
{
    auto dbs = all();
    scope(exit) teardown(dbs);
    foreach(db; dbs)
    {
        db.execute("insert into models(name) values('Some Name One');");
        db.execute("insert into models(name) values('Some Name Two');");
        Model[] models = db.list!(Model, "none/list.sql")();
        assert(models.length == 2);
        assert(models[1].name == "Some Name One");
        assert(models[0].name == "Some Name Two");
    }
}

/* Variant Parameters */

// void execute(string, Variant);
unittest
{
    auto dbs = all();
    scope(exit) teardown(dbs);
    foreach(db; dbs)
    {
        db.execute!("variant/insert.sql")(Variant("Some Variant Name"));
        Model model = db.single!(Model, "variant/single.sql")();
        assert(model.name == "Some Variant Name");
    }
}

// void execute(string, Variant[]);
unittest
{
    auto dbs = all();
    scope(exit) teardown(dbs);
    foreach(db; dbs)
    {
        db.execute!("variant/insert-many.sql")(variantArray("Some Variant Name", "Some Variant Title"));
        Model model = db.single!(Model)("select * from models order by id desc limit 1");
        assert(model.name == "Some Variant Name");
        assert(model.title == "Some Variant Title");
    }
}

// T single(T)(string, Variant);
unittest
{
    auto dbs = all();
    scope(exit) teardown(dbs);
    foreach(db; dbs)
    {
        db.execute("insert into models(name) values('some filter name');");
        Model model = db.single!(Model, "variant/single-by-name.sql")(Variant("some filter name"));
        assert(model.name == "some filter name");
    }
}

// T single(T)(string, Variant[]);
unittest
{
    auto dbs = all();
    scope(exit) teardown(dbs);
    foreach(db; dbs)
    {
        db.execute("insert into models(name, title) values('some filter name', 'some filter title');");
        Model model = db.single!(Model, "variant/single-by-many.sql")(variantArray("some filter name", "some filter title"));
        assert(model.name == "some filter name");
        assert(model.title == "some filter title");
    }
}

// T[] list(T)(string, Variant);
unittest
{
    auto dbs = all();
    scope(exit) teardown(dbs);
    foreach(db; dbs)
    {
        db.execute("insert into models(name, title) values('some name', 'some first title');");
        db.execute("insert into models(name, title) values('some name', 'some second title');");
        Model[] models = db.list!(Model, "variant/list.sql")(Variant("some name"));
        assert(models[0].name == "some name");
        assert(models[0].title == "some second title");
        assert(models[1].name == "some name");
        assert(models[1].title == "some first title");
    }
}

// T[] list(T)(string, Variant[]);
unittest
{
    auto dbs = all();
    scope(exit) teardown(dbs);
    foreach(db; dbs)
    {
        db.execute("insert into models(name, title) values('some name', 'some title');");
        db.execute("insert into models(name, title) values('some name', 'some title');");
        Model[] models = db.list!(Model, "variant/list-by-many.sql")(variantArray("some name", "some title")
        );
        assert(models[0].name == "some name");
        assert(models[0].title == "some title");
        assert(models[1].name == "some name");
        assert(models[1].title == "some title");
    }
}

/* Model Parameters */

// void execute(T)(string, T);
unittest
{
    auto dbs = all();
    scope(exit) teardown(dbs);
    foreach(db; dbs)
    {
        Model model = new Model();
        model.name = "some name";
        model.title = "some title";

        db.execute!(Model, "model/insert.sql")(model);

        Model insertedModel = db.single!(Model)("select * from models;");
        assert(insertedModel.name == "some name");
        assert(insertedModel.title == "some title");
    }
}

// T single(T)(string, T);
unittest
{
    auto dbs = all();
    scope(exit) teardown(dbs);
    foreach(db; dbs)
    {
        db.execute("insert into models(name) values('some name');");
        Model model = new Model();
        model.name = "some name";
        Model insertedModel = db.single!(Model, "model/single.sql")(model);
        assert(model.name == "some name");
    }
}

// T[] list(T)(string, T);
unittest
{
    auto dbs = all();
    scope(exit) teardown(dbs);
    foreach(db; dbs)
    {
        db.execute("insert into models(name) values('some name');");
        db.execute("insert into models(name) values('some name');");
        Model model = new Model();
        model.name = "some name";
        Model[] insertedModels = db.list!(Model, "model/list.sql")(model);
        assert(insertedModels[0].name == "some name");
        assert(insertedModels[1].name == "some name");
    }
}

unittest
{
    auto dbs = all();
    scope(exit) teardown(dbs);
    foreach(db; dbs)
    {
        db.execute("insert into models(name) values('some name');");
        string name = db.single!(string)("select name from models order by id desc limit 1");
        assert(name == "some name");
    }
}

version(unittest)
{
    class BindModel
    {
        int id;
        @bind("name") string notName;
    }
}

unittest
{
    auto dbs = all();
    scope(exit) teardown(dbs);
    foreach(db; dbs)
    {
        db.execute("insert into models(name) values('some name');");
        BindModel model = db.single!(BindModel)("select * from models order by id desc limit 1;");
        assert(model.notName == "some name");
    }
}

version(unittest)
{
    class FullModel
    {
        /* These are all of the supported types */
        /* Note that PostgreSQL doesn't support unsigned numeric types */
        int id;
        float float_column;
        double double_column;
        bool bool_column;
        long long_column;
        ulong ulong_column;
        int int_column;
        uint uint_column;
        short short_column;
        ushort ushort_column;
        byte byte_column;
        ubyte ubyte_column;
        ubyte[] ubytes_column;
        string string_column;
        DateTime datetime_column;

        this() { }

        this(float fc, double d, bool b, long l, ulong ul, int i, uint ui, short s, ushort us, byte bt, ubyte ub, ubyte[] ubs, string st, DateTime dt)
        {
            this.float_column = fc;
            this.double_column = d;
            this.bool_column = b;
            this.long_column = l;
            this.ulong_column = ul;
            this.int_column = i;
            this.uint_column = ui;
            this.short_column = s;
            this.ushort_column = us;
            this.byte_column = bt;
            this.ubyte_column = ub;
            this.ubytes_column = ubs;
            this.string_column = st;
            this.datetime_column = dt;
        }
    }
}

unittest
{
    auto sqlite = createSqliteConnection();
    scope(exit) sqlite.execute("drop table if exists full_models;");
    sqlite.execute("
        create table if not exists full_models(
            id integer primary key autoincrement not null,
            float_column float,
            double_column double,
            bool_column boolean,
            long_column long,
            ulong_column ulong,
            int_column integer,
            uint_column uint,
            short_column short,
            ushort_column ushort,
            byte_column byte,
            ubyte_column ubyte,
            ubytes_column blob,
            string_column string,
            datetime_column datetime
        );
    ");

    auto dateTime = DateTime(1999, 7, 6, 9);
    FullModel model = new FullModel(0.2f, 3.40483, true, 1_000_000L, 1_000_000UL, 2, to!(uint)(2),
        to!(short)(2), to!(ushort)(2), to!(byte)(2), to!(ubyte)(2), [1, 2, 3], "test string", dateTime
    );

    sqlite.execute!(FullModel)("insert into full_models values(
        null,
        ?(float_column),  ?(double_column), ?(bool_column),  ?(long_column),   ?(ulong_column),
        ?(int_column),    ?(uint_column),   ?(short_column), ?(ushort_column), ?(byte_column), ?(ubyte_column),
        ?(ubytes_column), ?(string_column), ?(datetime_column));
    ", model);

    FullModel insertedModel = sqlite.single!(FullModel)("select * from full_models order by id desc limit 1");
    assert(insertedModel.float_column == 0.2f);
    assert(insertedModel.double_column == 3.40483);
    assert(insertedModel.bool_column == true);
    assert(insertedModel.long_column == 1_000_000L);
    assert(insertedModel.ulong_column == 1_000_000UL);
    assert(insertedModel.int_column == 2);
    assert(insertedModel.uint_column == to!(uint)(2));
    assert(insertedModel.short_column == to!(short)(2));
    assert(insertedModel.ushort_column == to!(ushort)(2));
    assert(insertedModel.byte_column == to!(byte)(2));
    assert(insertedModel.ubyte_column == to!(ubyte)(2));
    assert(insertedModel.ubytes_column == [1,2,3]);
    assert(insertedModel.string_column == "test string");
    assert(insertedModel.datetime_column == DateTime(1999, 7, 6, 9));
}

unittest
{
    auto postgres = createPostgresConnection();
    scope(exit) postgres.execute("drop table if exists full_models;");
    postgres.execute("
        create table if not exists full_models(
            id serial primary key,
            float_column real,
            double_column double precision,
            bool_column boolean,
            long_column bigint,
            int_column integer,
            short_column smallint,
            byte_column smallint,
            string_column text,
            datetime_column timestamp
        );
    ");

    auto dateTime = DateTime(1999, 7, 6, 9);
    FullModel model = new FullModel(0.2f, 3.40483, true, 1_000_000L, 1_000_000UL, 2, to!(uint)(2),
        to!(short)(2), to!(ushort)(2), to!(byte)(2), to!(ubyte)(2), [1,2,3], "test string", dateTime
    );

    postgres.execute!(FullModel)("insert into full_models values(
        default,       ?(float_column), ?(double_column), ?(bool_column),   ?(long_column),
        ?(int_column), ?(short_column), ?(byte_column),   ?(string_column), ?(datetime_column));
    ", model);

    FullModel insertedModel = postgres.single!(FullModel)("select * from full_models order by id desc limit 1");
    assert(insertedModel.float_column == 0.2f);
    assert(insertedModel.double_column == 3.40483);
    assert(insertedModel.bool_column == true);
    assert(insertedModel.long_column == 1_000_000L);
    assert(insertedModel.int_column == 2);
    assert(insertedModel.short_column == to!(short)(2));
    assert(insertedModel.byte_column == to!(byte)(2));
    assert(insertedModel.string_column == "test string");
    assert(insertedModel.datetime_column == DateTime(1999, 7, 6, 9));
    postgres.execute("drop table if exists full_models;");
}

unittest
{
    auto mysql = createMysqlConnection();
    scope(exit) mysql.execute("drop table if exists full_models;");
    mysql.execute("
        create table if not exists full_models(
            id int not null auto_increment primary key,
            float_column float,
            double_column double,
            bool_column boolean,
            long_column bigint,
            ulong_column bigint unsigned,
            int_column integer, uint_column int unsigned,
            short_column mediumint,
            ushort_column mediumint unsigned,
            byte_column tinyint,
            ubyte_column tinyint unsigned,
            ubytes_column blob,
            string_column varchar(100),
            datetime_column datetime
        );
    ");

    auto dateTime = DateTime(1999, 7, 6, 9);
    FullModel model = new FullModel(0.2f, 3.40483, true, 1_000_000L, 1_000_000UL, 2, to!(uint)(2),
        to!(short)(2), to!(ushort)(2), to!(byte)(2), to!(ubyte)(2), [1,2,3], "test string", dateTime
    );

    mysql.execute!(FullModel)("insert into full_models values(
        null, ?(float_column),  ?(double_column), ?(bool_column),  ?(long_column),   ?(ulong_column),
              ?(int_column),    ?(uint_column),   ?(short_column), ?(ushort_column), ?(byte_column), ?(ubyte_column),
              ?(ubytes_column), ?(string_column), ?(datetime_column));
    ", model);

    FullModel insertedModel = mysql.single!(FullModel)("select * from full_models order by id desc limit 1");
    assert(insertedModel.float_column == 0.2f);
    assert(insertedModel.double_column == 3.40483);
    assert(insertedModel.bool_column == true);
    assert(insertedModel.long_column == 1_000_000L);
    assert(insertedModel.ulong_column == 1_000_000UL);
    assert(insertedModel.int_column == 2);
    assert(insertedModel.uint_column == to!(uint)(2));
    assert(insertedModel.short_column == to!(short)(2));
    assert(insertedModel.ushort_column == to!(ushort)(2));
    assert(insertedModel.byte_column == to!(byte)(2));
    assert(insertedModel.ubyte_column == to!(ubyte)(2));
    assert(insertedModel.ubytes_column == [1,2,3]);
    assert(insertedModel.string_column == "test string");
    assert(insertedModel.datetime_column == DateTime(1999, 7, 6, 9));
}
