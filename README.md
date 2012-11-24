sp_SDS
======

Stored procedure written for MS SQL Server to report on database disk utilization.

I originally wrote about this stored procedure here:

http://www.ryanfrantz.com/2012/03/04/sql-server-database-storage-utilization-via-sp_sds-part-1/

Source
------
`sp_SDS` was originally written by Richard Ding; I have extended it with code lifted from the `sp_spaceused` stored procedure to monitor various aspects of a SQL Server and its databases' storage utilization.

Execution
---------
`sp_SDS` can be run with no arguments, or with various arguments, depending on the desired output.

No Arguments
------------
`exec sp_SDS`

This results in output similar to the following (**two result sets**):

_All values are measured in megabytes (MB)._

<table>
<tr><th>**WEIGHT (%)**</th><th>**DATABASE**</th><th>**DATABASE USED  (%)**</th><th>**+**</th><th>**DATABASE FREE  (%)**</th><th>****</th><th>**DATABASE TOTAL**</th><th>****</th><th>**DATA  (used,  %)**</th><th>**+**</th><th>**LOG  (used,  %)**</th></tr>
<tr><td>0.01</td><td>master</td><td>3.46  (69.20 %)</td><td>+</td><td>1.54  (30.80 %)</td><td>=</td><td>5.00</td><td>=</td><td>4.00  (2.94,  73.50%)</td><td>+</td><td>1.00  (0.52,  52.00%)</td></tr>
<tr><td>0.00</td><td>model</td><td>1.69  (96.57 %)</td><td>+</td><td>0.06  (3.43 %</td><td>=</td><td>1.75</td><td>=</td><td>1.25  (1.25,  100.00%)</td><td>+</td><td>0.50  (0.44,  88.00%)</td></tr>
<tr><td>0.09</td><td>msdb</td><td>29.48  (83.35 %)</td><td>+</td><td>5.89  (16.65 %)</td><td>=</td><td>35.37</td><td>=</td><td>30.31  (27.63,  91.16%)</td><td>+</td><td>5.06  (1.85,  36.56%)</td></tr>
<tr><td>14.79</td><td>poobah</td><td>5440.47  (88.64 %)</td><td>+</td><td>697.53  (11.36 %)</td><td>=</td><td>6138.00</td><td>=</td><td>5525.81  (5426.94,  98.21%)</td><td>+</td><td>612.19  (13.53,  2.21%)</td></tr>
<tr><td>0.02</td><td>ReportServer</td><td>3.90  (41.58 %)</td><td>+</td><td>5.48  (58.42 %)</td><td>=</td><td>9.38</td><td>=</td><td>3.25  (2.88,  88.62%)</td><td>+</td><td>6.13  (1.02,  16.64%)</td></tr>
<tr><td>0.01</td><td>ReportServerTempDB</td><td>1.83  (61.00 %)</td><td>+</td><td>1.17  (39.00 %)</td><td>=</td><td>3.00</td><td>=</td><td>2.25  (1.44,  64.00%)</td><td>+</td><td>0.75  (0.39,  52.00%)</td></tr>
<tr><td>0.13</td><td>tempdb</td><td>4.63  (8.86 %)</td><td>+</td><td>47.62  (91.14 %)</td><td>=</td><td>52.25</td><td>=</td><td>49.75  (2.94,  5.91%)</td><td>+</td><td>2.50  (1.69,  67.60%)</td></tr>
<tr><td>84.95</td><td>xanadu</td><td>21912.05  (62.15 %)</td><td>+</td><td>13345.51  (37.85 %)</td><td>=</td><td>35257.56</td><td>=</td><td>29236.00  (21845.81,  74.72%)</td><td>+</td><td>6021.56  (66.24,  1.10%)</td></tr>
</table>
----
<table>
<tr><th>**SUM**</th><th>**USED**</th><th>**FREE**</th><th>**TOTAL**</th><th>**DATA**</th><th>**LOG**</th></tr>
<tr><td>MB</td><td>27397.51</td><td>14104.80</td><td>41502.31</td><td>34852.62</td><td>6649.69</td></tr>
</table>

=== Argument: `@mode = 'simple'` ===
If the default output contains more information than you'd like, pass the argument `@mode = 'simple'` to `sp_SDS`:
`exec sp_SDS @mode = 'simple'`

This results in __**truncated**__ output similar to the following (**two result sets**):

_All values are measured in megabytes (MB)._

<table>
<tr><th>**DATABASE**</th><th>**TOTAL**</th><th>****</th><th>**DATA  (used,  %)**</th><th>**+**</th><th>**LOG  (used,  %)**</th></tr>
<tr><td>master</td><td>5.00</td><td>=</td><td>4.00  (2.94,  73.50%)</td><td>+</td><td>1.00  (0.52,  52.00%)</td></tr>
<tr><td>model</td><td>1.75</td><td>=</td><td>1.25  (1.25,  100.00%)</td><td>+</td><td>0.50  (0.44,  88.00%)</td></tr>
<tr><td>msdb</td><td>35.37</td><td>=</td><td>30.31  (27.63,  91.16%)</td><td>+</td><td>5.06  (1.85,  36.56%)</td></tr>
<tr><td>poobah</td><td>6138.00</td><td>=</td><td>5525.81  (5426.94,  98.21%)</td><td>+</td><td>612.19  (13.53,  2.21%)</td></tr>
<tr><td>ReportServer</td><td>9.38</td><td>=</td><td>3.25  (2.88,  88.62%)</td><td>+</td><td>6.13  (1.02,  16.64%)</td></tr>
<tr><td>ReportServerTempDB</td><td>3.00</td><td>=</td><td>2.25  (1.44,  64.00%)</td><td>+</td><td>0.75  (0.39,  52.00%)</td></tr>
<tr><td>tempdb</td><td>52.25</td><td>=</td><td>49.75  (2.94,  5.91%)</td><td>+</td><td>2.50  (1.69,  67.60%)</td></tr>
<tr><td>xanadu</td><td>35257.56</td><td>=</td><td>29236.00  (21845.81,  74.72%)</td><td>+</td><td>6021.56  (66.24,  1.10%)</td></tr>
</table>

----

<table>
<tr><th>**SUM**</th><th>**USED**</th><th>**FREE**</th><th>**TOTAL**</th><th>**DATA**</th><th>**LOG**</th></tr>
<tr><td>MB</td><td>27397.51</td><td>14104.80</td><td>41502.31</td><td>34852.62</td><td>6649.69</td></tr>
</table>

=== Argument: <Database Name> ===
`sp_SDS` will accept a single database name as an argument:
`
exec sp_SDS poobah
`

This results in output similar to the following:

_All values are measured in megabytes (MB)._
 |**WEIGHT (%)**|**DATABASE**|**DATABASE USED  (%)**|**+**|**DATABASE FREE  (%)**|****|**DATABASE TOTAL**|****|**DATA  (used,  %)**|**+**|**LOG  (used,  %)**|
 |100.00|poobah|5440.77  (88.64 %)|+|697.23  (11.36 %)|=|6138.00|=|5525.81  (5427.06,  98.21%)|+|612.19  (13.71,  2.24%)|

Alternatively, the `@mode = 'simple' argument can be used in addition to the database name argument:
`
exec sp_SDS poobah, @mode = 'simple'
`

Resulting in:
 |**DATABASE**|**DATABASE TOTAL**|****|**DATA  (used,  %)**|**+**|**LOG  (used,  %)**|
 |poobah|6138.00|=|5525.81  (5427.06,  98.21%)|+|612.19  (13.71,  2.24%)|


=== Argument: `@nagios = 'true'` ===
**`sp_SDS`...  Now with __Nagios__ support! **

The output generated by `sp_SDS` is great for human consumption; for Nagios lovers, the output needed a little bit of reorganization so that the individual data elements can be easily parsed.

==== `@nagios = 'true'` ====
Calling `sp_SDS` with `@nagios = 'true'`:
`
exec sp_SDS @nagios = 'true'
`

results in output similar to the following:

_All values are measured in megabytes (MB)._
 |**WEIGHT (%)**|**DATABASE**|**DATABASE USED**|**DATABASE FREE**|**DATABASE TOTAL**|**DATABASE USED  (%)**|**DATABASE FREE  (%)**|**DATA TOTAL**|**DATA USED**|**DATA USED  (%)**|**LOG TOTAL**|**LOG USED**|**LOG USED  (%)**|
 |0.01|master|3.59|1.41|5.00|71.80|28.20|4.00|2.94|73.50|1.00|0.65|65.00|
 |0.00|model|1.69|0.06|1.75|96.57|3.43|1.25|1.25|100.00|0.50|0.44|88.00|
 |0.10|msdb|35.77|6.04|41.81|85.55|14.45|36.75|33.69|91.67|5.06|2.08|41.11|
 |14.79|poobah|5462.99|675.01|6138.00|89.00|11.00|5525.81|5456.19|98.74|612.19|6.80|1.11|
 |0.02|ReportServer|3.92|5.46|9.38|41.79|58.21|3.25|2.88|88.62|6.13|1.04|16.97|
 |0.01|ReportServerTempDB|1.84|1.16|3.00|61.33|38.67|2.25|1.44|64.00|0.75|0.40|53.33|
 |0.13|tempdb|5.29|46.96|52.25|10.12|89.88|49.75|3.88|7.80|2.50|1.41|56.40|
 |84.94|xanadu|21888.92|13368.64|35257.56|62.08|37.92|29236.00|21845.56|74.72|6021.56|43.36|0.72|

==== `@Mode = 'simple', @nagios = 'true'` ====
`sp_SDS` can be called with `@Mode = 'simple', @nagios = 'true'` to limit the data output for Nagios.
`
exec sp_SDS @Mode = 'simple', @nagios = 'true'
`

This results in output similar to the following:

_All values are measured in megabytes (MB)._
 |**DATABASE**|**DATABASE TOTAL**|**DATA TOTAL**|**DATA USED**|**DATA USED  (%)**|**LOG TOTAL**|**LOG USED**|**LOG USED  (%)**|
 |master|5.00|4.00|2.94|73.50|1.00|0.55|55.00|
 |model|1.75|1.25|1.25|100.00|0.50|0.44|88.00|
 |msdb|41.81|36.75|33.69|91.67|5.06|1.95|38.54|
 |poobah|6690.63|6078.44|5465.69|89.92|612.19|9.00|1.47|
 |ReportServer|9.38|3.25|2.88|88.62|6.13|1.04|16.97|
 |ReportServerTempDB|3.00|2.25|1.44|64.00|0.75|0.41|54.67|
 |tempdb|52.25|49.75|3.31|6.65|2.50|1.09|43.60|
 |xanadu|35257.56|29236.00|21845.56|74.72|6021.56|43.36|0.72|

==== `<Database Name>, @Mode = 'simple', @nagios = 'true'` ====
To further restrict the output to a specific database, pass `<Database Name>, @Mode = 'simple', @nagios = 'true'` to `sp_SDS`:
`
exec sp_SDS poobah, @Mode = 'simple', @nagios = 'true'
`

This results in output similar to the following:

_All values are measured in megabytes (MB)._
 |**DATABASE**|**DATABASE TOTAL**|**DATA TOTAL**|**DATA USED**|**DATA USED  (%)**|**LOG TOTAL**|**LOG USED**|**LOG USED  (%)**|
 |poobah|6690.63|6078.44|5465.69|89.92|612.19|9.00|1.47|

=== Argument: `@allocation_stats = 'true'` ===
To find out how much storage is allocated to a given database (including data, indexes, and logs), from the available __**physical**__ allocation, pass the argument `@allocation_stats = 'true'` to `sp_SDS`:

`
exec sp_SDS poobah, @allocation_stats = 'true'
`

This results in output similar to the following:

_All values are measured in megabytes (MB)._
 |**database_name**|**database_size**|**unallocated space**|
 |poobah|6138.00 MB|0.00 MB|

**NOTE: Use of the `@allocation_stats = 'true'` argument __REQUIRES__ that a database name be specified.**

=== Argument: `@reserved_stats = 'true'` ===
To determine how much storage is reserved by a database, its data, and indexes, pass the argument `@reserved_stats = 'true'` to `sp_SDS`.
`
exec sp_SDS xanadu, @reserved_stats = 'true'
`

This results in output similar to the following:

_All values are measured in kilobytes (KB)._
 |**reserved**|**data**|**index_size**|**unused**|
 |5973920 KB|3450408 KB|1879920 KB|643592 KB|

**NOTE: Use of the `@allocation_stats = 'true'` argument __REQUIRES__ that a database name be specified.**

= TODO =

**Determine why the results of `@allocation_stats = 'true'` and `@reserved_stats = 'true'` don't jibe.**

**EXAMPLE: `@allocation_stats = 'true'` shows `database_size` = __6138.00 MB__ and `unallocated space` = __0.00 MB__ while `@reserved_stats = 'true'` shows `reserved` = __5833.90 MB__ (manually calculated as 5973920 KB / 1024).  Where is the remaining __~305 MB__?**
