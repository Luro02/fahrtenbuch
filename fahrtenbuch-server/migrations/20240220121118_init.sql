-- Create users table.
create table if not exists users
(
    id integer primary key not null,
    username text not null unique,
    password text not null
);

-- Create trip_users table. This table keeps track of the users who have participated in a trip.
create table if not exists trip_users
(
    trip_id integer not null,
    user_id integer not null,

    constraint PK_trip_users primary key (trip_id, user_id),
    constraint FK_trip_id foreign key(trip_id) references trips(id),
    constraint FK_user_id foreign key(user_id) references users(id)
);

-- Create trips table.
create table if not exists trips
(
    id integer primary key not null,
    created_at datetime not null,
    start integer not null unique,
    end integer not null unique,
    description text
);

-- Create expense_users table. This table keeps track of the users who have paid for a expense.
create table if not exists expense_users
(
    expense_id integer not null,
    user_id integer not null,

    constraint PK_expense_users primary key (expense_id, user_id),
    constraint FK_expense_id foreign key(expense_id) references expenses(id),
    constraint FK_user_id foreign key(user_id) references users(id)
);


-- Create expenses table.
create table if not exists expenses
(
    id integer primary key not null,
    created_at datetime not null,
    amount integer not null unique,
    description text
);
