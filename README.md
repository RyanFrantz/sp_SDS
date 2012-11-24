# sp_SDS #

Stored procedure written for MS SQL Server to report on database disk utilization.

I originally wrote about this stored procedure here:

http://www.ryanfrantz.com/2012/03/04/sql-server-database-storage-utilization-via-sp_sds-part-1/

## Source ##
`sp_SDS` was originally written by Richard Ding; I have extended it with code lifted from the `sp_spaceused` stored procedure to monitor various aspects of a SQL Server and its databases' storage utilization.

## Execution ##
`sp_SDS` can be run with no arguments, or with various arguments, depending on the desired output.

### No Arguments ###
`exec sp_SDS`

This results in output similar to the following (**two result sets**):

_All values are measured in megabytes (MB)._

<table>
<tr><th>WEIGHT (%)</th><th>DATABASE</th><th>DATABASE USED  (%)</th><th>+</th><th>DATABASE FREE  (%)</th><th></th><th>DATABASE TOTAL</th><th></th><th>DATA  (used,  %)</th><th>+</th><th>LOG  (used,  %)</th></tr>
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
<tr><th>SUM</th><th>USED</th><th>FREE</th><th>TOTAL</th><th>DATA</th><th>LOG</th></tr>
<tr><td>MB</td><td>27397.51</td><td>14104.80</td><td>41502.31</td><td>34852.62</td><td>6649.69</td></tr>
</table>

### Argument: `@mode = 'simple'` ###
If the default output contains more information than you'd like, pass the argument `@mode = 'simple'` to `sp_SDS`:

`exec sp_SDS @mode = 'simple'`

This results in __**truncated**__ output similar to the following (**two result sets**):

_All values are measured in megabytes (MB)._

<table>
<tr><th>DATABASE</th><th>TOTAL</th><th></th><th>DATA  (used,  %)</th><th>+</th><th>LOG  (used,  %)</th></tr>
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
<tr><th>SUM</th><th>USED</th><th>FREE</th><th>TOTAL</th><th>DATA</th><th>LOG</th></tr>
<tr><td>MB</td><td>27397.51</td><td>14104.80</td><td>41502.31</td><td>34852.62</td><td>6649.69</td></tr>
</table>

### Argument: database ###

`sp_SDS` will accept a single database name as an argument:

`exec sp_SDS poobah`

This results in output similar to the following:

_All values are measured in megabytes (MB)._

<table>
<tr><th>WEIGHT (%)</th><th>DATABASE</th><th>DATABASE USED  (%)</th><th>+</th><th>DATABASE FREE  (%)</th><th></th><th>DATABASE TOTAL</th><th></th><th>DATA  (used,  %)</th><th>+</th><th>LOG  (used,  %)</th></tr>
<tr><td>100.00</td><td>poobah</td><td>5440.77  (88.64 %)</td><td>+</td><td>697.23  (11.36 %)</td><td>=</td><td>6138.00</td><td>=</td><td>5525.81  (5427.06,  98.21%)</td><td>+</td><td>612.19  (13.71,  2.24%)</td></tr>
</table>

Alternatively, the `@mode = 'simple' argument can be used in addition to the database name argument:

`exec sp_SDS poobah, @mode = 'simple'`

Resulting in:

<table>
<tr><th>DATABASE</th><th>DATABASE TOTAL</th><th></th><th>DATA  (used,  %)</th><th>+</th><th>LOG  (used,  %)</th></tr>
<tr><td>poobah</td><td>6138.00</td><td>=</td><td>5525.81  (5427.06,  98.21%)</td><td>+</td><td>612.19  (13.71,  2.24%)</td></tr>
</table>


### Argument: `@nagios = 'true'` ###
`sp_SDS`...  Now with __Nagios__ support!

The output generated by `sp_SDS` is great for human consumption; for Nagios lovers, the output needed a little bit of reorganization so that the individual data elements can be easily parsed.

#### `@nagios = 'true'` ####
Calling `sp_SDS` with `@nagios = 'true'`:

`exec sp_SDS @nagios = 'true'`

results in output similar to the following:

_All values are measured in megabytes (MB)._

<table>
<tr><th>WEIGHT (%)</th><th>DATABASE</th><th>DATABASE USED</th><th>DATABASE FREE</th><th>DATABASE TOTAL</th><th>DATABASE USED  (%)</th><th>DATABASE FREE  (%)</th><th>DATA TOTAL</th><th>DATA USED</th><th>DATA USED  (%)</th><th>LOG TOTAL</th><th>LOG USED</th><th>LOG USED  (%)</th></tr>
<tr><td>0.01</td><td>master</td><td>3.59</td><td>1.41</td><td>5.00</td><td>71.80</td><td>28.20</td><td>4.00</td><td>2.94</td><td>73.50</td><td>1.00</td><td>0.65</td><td>65.00</td></tr>
<tr><td>0.00</td><td>model</td><td>1.69</td><td>0.06</td><td>1.75</td><td>96.57</td><td>3.43</td><td>1.25</td><td>1.25</td><td>100.00</td><td>0.50</td><td>0.44</td><td>88.00</td></tr>
<tr><td>0.10</td><td>msdb</td><td>35.77</td><td>6.04</td><td>41.81</td><td>85.55</td><td>14.45</td><td>36.75</td><td>33.69</td><td>91.67</td><td>5.06</td><td>2.08</td><td>41.11</td></tr>
<tr><td>14.79</td><td>poobah</td><td>5462.99</td><td>675.01</td><td>6138.00</td><td>89.00</td><td>11.00</td><td>5525.81</td><td>5456.19</td><td>98.74</td><td>612.19</td><td>6.80</td><td>1.11</td></tr>
<tr><td>0.02</td><td>ReportServer</td><td>3.92</td><td>5.46</td><td>9.38</td><td>41.79</td><td>58.21</td><td>3.25</td><td>2.88</td><td>88.62</td><td>6.13</td><td>1.04</td><td>16.97</td></tr>
<tr><td>0.01</td><td>ReportServerTempDB</td><td>1.84</td><td>1.16</td><td>3.00</td><td>61.33</td><td>38.67</td><td>2.25</td><td>1.44</td><td>64.00</td><td>0.75</td><td>0.40</td><td>53.33</td></tr>
<tr><td>0.13</td><td>tempdb</td><td>5.29</td><td>46.96</td><td>52.25</td><td>10.12</td><td>89.88</td><td>49.75</td><td>3.88</td><td>7.80</td><td>2.50</td><td>1.41</td><td>56.40</td></tr>
<tr><td>84.94</td><td>xanadu</td><td>21888.92</td><td>13368.64</td><td>35257.56</td><td>62.08</td><td>37.92</td><td>29236.00</td><td>21845.56</td><td>74.72</td><td>6021.56</td><td>43.36</td><td>0.72</td></tr>
</table>

#### `@Mode = 'simple', @nagios = 'true'` ####

`sp_SDS` can be called with `@Mode = 'simple', @nagios = 'true'` to limit the data output for Nagios.

`exec sp_SDS @Mode = 'simple', @nagios = 'true'`

This results in output similar to the following:

_All values are measured in megabytes (MB)._

<table>
<tr>DATABASE</th><th>DATABASE TOTAL</th><th>DATA TOTAL</th><th>DATA USED</th><th>DATA USED  (%)</th><th>LOG TOTAL</th><th>LOG USED</th><th>LOG USED  (%)</th></tr>
<tr><td>master</td><td>5.00</td><td>4.00</td><td>2.94</td><td>73.50</td><td>1.00</td><td>0.55</td><td>55.00</td></tr>
<tr><td>model</td><td>1.75</td><td>1.25</td><td>1.25</td><td>100.00</td><td>0.50</td><td>0.44</td><td>88.00</td></tr>
<tr><td>msdb</td><td>41.81</td><td>36.75</td><td>33.69</td><td>91.67</td><td>5.06</td><td>1.95</td><td>38.54</td></tr>
<tr><td>poobah</td><td>6690.63</td><td>6078.44</td><td>5465.69</td><td>89.92</td><td>612.19</td><td>9.00</td><td>1.47</td></tr>
<tr><td>ReportServer</td><td>9.38</td><td>3.25</td><td>2.88</td><td>88.62</td><td>6.13</td><td>1.04</td><td>16.97</td></tr>
<tr><td>ReportServerTempDB</td><td>3.00</td><td>2.25</td><td>1.44</td><td>64.00</td><td>0.75</td><td>0.41</td><td>54.67</td></tr>
<tr><td>tempdb</td><td>52.25</td><td>49.75</td><td>3.31</td><td>6.65</td><td>2.50</td><td>1.09</td><td>43.60</td></tr>
<tr><td>xanadu</td><td>35257.56</td><td>29236.00</td><td>21845.56</td><td>74.72</td><td>6021.56</td><td>43.36</td><td>0.72</td></tr>
</table>

#### `database, @Mode = 'simple', @nagios = 'true'` ####

To further restrict the output to a specific database, pass `<Database Name>, @Mode = 'simple', @nagios = 'true'` to `sp_SDS`:

`exec sp_SDS poobah, @Mode = 'simple', @nagios = 'true'`

This results in output similar to the following:

_All values are measured in megabytes (MB)._

<table>
<tr><th>DATABASE</th><th>DATABASE TOTAL</th><th>DATA TOTAL</th><th>DATA USED</th><th>DATA USED  (%)</th><th>LOG TOTAL</th><th>LOG USED</th><th>LOG USED  (%)</th></tr>
<tr><td>poobah</td><td>6690.63</td><td>6078.44</td><td>5465.69</td><td>89.92</td><td>612.19</td><td>9.00</td><td>1.47</td></tr>
</table>

### Argument: `@allocation_stats = 'true'` ###
To find out how much storage is allocated to a given database (including data, indexes, and logs), from the available __**physical**__ allocation, pass the argument `@allocation_stats = 'true'` to `sp_SDS`:

`exec sp_SDS poobah, @allocation_stats = 'true'`

This results in output similar to the following:

_All values are measured in megabytes (MB)._

<table>
<tr><th>database_name</th><th>database_size</th><th>unallocated space</th></tr>
<tr><td>poobah</td><td>6138.00 MB</td><td>0.00 MB</td></tr>
</table>

**NOTE: Use of the `@allocation_stats = 'true'` argument __REQUIRES__ that a database name be specified.**

### Argument: `@reserved_stats = 'true'` ###
To determine how much storage is reserved by a database, its data, and indexes, pass the argument `@reserved_stats = 'true'` to `sp_SDS`.

`exec sp_SDS xanadu, @reserved_stats = 'true'`

This results in output similar to the following:

_All values are measured in kilobytes (KB)._

<table>
<tr><th>reserved</th><th>data</th><th>index_size</th><th>unused</th></tr>
<tr><td>5973920 KB</td><td>3450408 KB</td><td>1879920 KB</td><td>643592 KB</td></tr>
</table>

**NOTE: Use of the `@allocation_stats = 'true'` argument __REQUIRES__ that a database name be specified.**

# TODO #

**Determine why the results of `@allocation_stats = 'true'` and `@reserved_stats = 'true'` don't jibe.**

**EXAMPLE: `@allocation_stats = 'true'` shows `database_size` = __6138.00 MB__ and `unallocated space` = __0.00 MB__ while `@reserved_stats = 'true'` shows `reserved` = __5833.90 MB__ (manually calculated as 5973920 KB / 1024).  Where is the remaining __~305 MB__?**
