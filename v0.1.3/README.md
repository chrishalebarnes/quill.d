Quill.d
===================================================================

[Quill.d](https://github.com/chrishalebarnes/quill.d) is a data access library for [the D programming language](http://dlang.org/) that sits on top of [DDBC](https://github.com/buggins/ddbc). After getting set up you'll be able to write plain SQL in a file or a string, and run it. Quill.d embraces SQL as a language and does not attempt to abstract the database away. As it turns out, SQL is a pretty good language in which to query a database.

Here are a few high level examples:

**Fetch some records**

```
auto models = database.list!(Model, "list.sql")();
```

where `list.sql` contains

```
select * from models;
```

**Fetch a single record**

```
auto model = database.single!(Model, "select.sql")(Variant(4));
```

where `select.sql` contains

```
select * from models where id = ?;
```

**Insert a record**

```
database.execute!(Model, "insert.sql")(Variant("name"));
```

where `insert.sql` contains

```
insert into models(name) values(?);
```

## Getting Started
Add [Quill.d](https://github.com/chrishalebarnes/quill.d) to `dub.json`

```
{
    ...
    "dependencies": {
        "quill-d": "~>0.1.3"
    }
}
```

Specify a database configuration to use.

## PostgreSQL
Add the [PostgreSQL](http://www.postgresql.org/) configuration to `dub.json`

```
{
    ...
    "subConfigurations": {
        "quill-d": "PostgreSQL"
    }
}
```
**Install PostgreSQL Client**

If you don't already have it, install the PostgreSQL client

```
sudo apt-get install postgresql-client
```

On Linux you may get an error `cannot find -lpq`. The linker is having trouble finding the client library. To fix this, you can add a symlink like this:

```
ln -s /usr/lib/libpq.so.5 /usr/lib/libpq.so
```

**Create a new PostgreSQL client:**

```
import quill;
auto database = new Database("127.0.0.1", to!(ushort)(54320), "testdb", "admin", "password", true);
```

## MySQL
Add the [MySQL](https://www.mysql.com/) configuration to `dub.json`

```
{
    ...
    "subConfigurations": {
        "quill-d": "MySQL"
    }
}
```

**Create a new MySQL client:**

```
import quill;
auto database = new Database("127.0.0.1", to!(ushort)(33060), "testdb", "admin", "password");
```

## SQLite
Add the [SQLite](https://www.sqlite.org/) configuration to `dub.json`

```
{
    ...
    "subConfigurations": {
        "quill-d": "SQLite"
    }
}
```

**Install SQLite3**

If you don't already have it, install SQLite3

```
sudo apt-get install sqlite3 libsqlite3-dev
```

**Create a new SQLite client:**

```
import quill;
auto database = new Database("/path/to/db.sqlite3");
```

## Specify String Import Path
[Quill.d](https://github.com/chrishalebarnes/quill.d) uses string imports to run SQL statements in files embedded in the compiled binary. The paths must be added to `dub.json` to allow for those files to be imported as strings.

```
{
    ...
    "stringImportPaths": ["queries"]
}
```

SQL queries can now be imported and run relative to the `queries` directory like this:

```
database.execute!("statement.sql")();
```

## Running Tests
The test suite is a collection of integration tests that actually runs SQL in all of the supported databases. Other than SQLite, you'll have to have a database to connect to. If you do not have a database, you can use [Database Quickstart](https://github.com/chrishalebarnes/database-quickstart) to spin up a server for each supported database. The connection details are in the test [here](https://github.com/chrishalebarnes/quill.d/blob/master/source/quill/database.d#L667). Once there is a database to connect to, the test suite can be run in all of the supported databases from the command line like this:

    dub test

## Query Types and Parameters
There are a bunch of overloads that can handle various kinds of queries. They are divided up by the expected return type.

| Returns | Method Name |
| ------  |:-----------:|
| none    | `execute`   |
| many    | `list`      |
| one     | `single`    |

### Parameters
For each return type there can be no parameters, model based parameters, or `Variant` based parameters.

#### No Parameters Example
This will execute a SQL statement in `queries/statement.sql` that returns nothing and takes no parameters:

```
database.execute!("statement.sql")();
```

#### Model Based Parameters
Model based parameters can be used by making a class that has fields that map to the column names in the result and the parameter names in the query. In D, `bind` is used to specify the name of the parameter or the column name in a result set. In SQL, `?(parameter_name)` can be used to match the name of the field or the value of `bind`.

Given a class like this:

```
class Model
{
    int id;
    @(bind("name")) string name;
}
auto model = new Model();
model.name = "value";
```

It can map the fields of the class into a query like this:

```
database.execute!("statement.sql")(model);
```

where `statement.sql` looks like this:

```
insert into models(name) values(?(name));
```

It can also map the column names from the result of a query like this:

```
auto models = database.list!("statement.sql")();
```

where `statement.sql` looks like this:

```
select id, name from models;
```

#### Variant Based Parameters
`Variant` based parameters are ordered parameters that can be of any type.

Given a class like this:

```
class Model
{
    int id;
    @(bind("name")) string name;
}
```

A `Variant` or array of `Variant` will map to each parameter

```
auto model = database.single!("statement.sql")(Variant(4));
```

where `statement.sql` looks like this:

```
select * from models where id = ?;
```

#### More Examples
There are a ton more examples in the test and doc comments of [database.d](https://github.com/chrishalebarnes/quill.d/blob/master/source/quill/database.d).

## License and Copyright

See [license](https://github.com/chrishalebarnes/quill.d/blob/master/license)
