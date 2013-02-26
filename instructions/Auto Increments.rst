Auto Increments
======================

.. contents:: 
   :backlinks: entry
   :local:


Default autoinc behavior
--------------------------

Create a table with an auto-inc column node1::

	node1 mysql> create table autoinc ( i int unsigned not null auto_increment primary key, j char(32));
	node1 mysql> insert into autoinc (j) values ('aaaaa'),('bbbbb'),('ccccc');
	node1 mysql> select * from autoinc;

We can see staggered autoincrement values.  Try adding a row on node3 and then back on node1::

	node3 mysql> insert into autoinc (j) values ('ddddd');
	node1 mysql> insert into autoinc (j) values ('eeeeee');
	node1 mysql> select * from autoinc;

So, the auto_increment will jump to whatever the last entry was and start from there.  Notice how these variables are set on each node::

	mysql> show global variables like 'auto_increment%';

- How are those values adjusted if a node in the cluster stops?


Disabling auto_increment control
-----------------------------------

Set this in my.cnf on every node and do a rolling restart::

	wsrep_auto_increment_control    = OFF

Now, at precisely the same time (easiest if you have a terminal that will send the same input to two windows simutaneously), try to execute the following statements::

	node1 mysql> insert into autoinc (j) values ('node1');
	node3 mysql> insert into autoinc (j) values ('node3');

- Do they both go through?
- Any errors?
- Watch for brute force aborts in myq_gadgets, see any?
- If there is a BFA, why is the insert apparently going through?  Hint: wsrep_retry_autocommit.


Turn off autocommit and try the same thing.  Be sure 'commit' happens on both servers simultaneously::

	node1 mysql> set autocommit=0;
	node1 mysql> set autocommit=0;
	
	node1 mysql> insert into autoinc (j) values ('node1');
	node3 mysql> insert into autoinc (j) values ('node3');
	
	node1 mysql> commit;
	node3 mysql> commit;

- Any conflicts this time?
- What impact would turning off auto_increment control have?  When might it be safe?
