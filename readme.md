quill.d
===================

quill.d is a data access library that sits on top of [DDBC](https://github.com/buggins/ddbc) and leverages string imports.

## Getting Started
Add quill.d to dub.json
```json
{
    ...
    "dependencies": {
        "quill-d": "~>0.1.0"
    }
}
```

Specify a database configuration to use.

## PostgreSQL
```json
{
    ...
    "subConfigurations": {
        "quil-d": "PostgreSQL"
    }
}
```
**Create a new PostgreSQL client:**
`auto db = new Database(DatabaseType.PostgreSQL, "127.0.0.1", to!(ushort)(54320), "testdb", "admin", "password");`

## MySQL
```json
{
    ...
    "subConfigurations": {
        "quil-d": "MySQL"
    }
}
```
**Create a new MySQL client:**
`auto database = new Database(DatabaseType.MySQL, "127.0.0.1", to!(ushort)(33060), "testdb", "admin", "password");`

## SQLite
```json
{
    ...
    "subConfigurations": {
        "quil-d": "SQLite"
    }
}
```
**Create a new SQLite client:**
`auto database = new Database(DatabaseType.SQLite, "/path/to/db.sqlite3");`d

## Specify String Import Path
quill.d uses string imports to run SQL statements in files embedded in the binary. The paths must be added to `dub.json` to allow for those files to be imported as strings.

```json
{
    ...
    "stringImportPaths": ["queries"]
}
```
SQL queries can now be imported and run relative to the `queries` directory like this:

`database.execute!("statement.sql")();`

## Running Tests
The test suite is a collection of integration tests that actually runs SQL in all of the supported databases. Other than SQLite, you'll have to have a database to connect to. If you do not have a database, you can use [Database Quickstart](https://github.com/chrishalebarnes/database-quickstart) to spin up a server for each supported database. The connection details are in the test [here](https://github.com/chrishalebarnes/quill.d/blob/master/source/quill/database.d#L667). Once there is a database to connect to, the test suite can be run in all of the supported databases like this:

`dub test`

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

`database.execute!("statement.sql")()`

#### Model Based Parameters
Model based parameters can be used by making a class that has fields that map to the column names in the result and the parameter names in the query.

Given a class like this:
```D
class Model
{
    int id;
    @(bind("name")) string name;
}
auto model = new Model();
model.name = "value";
```

It can map it's fields into a query like this:
`database.execute!("statement.sql")(model);`

where `statement.sql` looks like this:
`insert into models(name) values(?(name));`

It can also map the resulting column names from the result of a query like this:
`auto models = database.list!("statement.sql");`

where `statement.sql` looks like this:
`select * from models;`

#### Variant Based Parameters
Variant based parameters are ordered parameters that can be of any type.

Given a class like this:
```D
class Model
{
    int id;
    @(bind("name")) string name;
}
```

A `Variant` or array of `Variant` will map to each parameter
`auto model = database.single!("statement.sql")(Variant(4));`

where `statement.sql` looks like this:
`select * from models where id = ?;`

#### More Examples
There are a ton more examples in the test and doc comments of [database.d](https://github.com/chrishalebarnes/quill.d/blob/master/source/quill/database.d).

##License and Copyright

See [license](https://github.com/chrishalebarnes/quill.d/blob/master/license)
