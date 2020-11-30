### sample python interface - pagerank

from ctypes import *

### load gunrock shared library - libgunrock
gunrock = cdll.LoadLibrary('stars_2total_separate')
### read in input CSR arrays from files
row_list = [int(x.strip()) for x in open('stars_2total_separate')]
col_list = [int(x.strip()) for x in open('stars_2total_separate')]
print ('set pointers')
### convert CSR graph inputs for gunrock input
row = pointer((c_int * len(row_list))(*row_list))
col = pointer((c_int * len(col_list))(*col_list))
nodes = len(row_list) - 1
edges = len(col_list)

### output array
node = pointer((c_int * nodes)())
rank = pointer((c_float * nodes)())

normalize = 1
print ('run gunrock')
### call gunrock function on device
elapsed = gunrock.snn(k, epsilon, min-pts)

### sample results
print ('elapsed: ' + str(elapsed))
print ('top page rank:')
for idx in range(nodes):
    print (node[0][idx])
    print (rank[0][idx])
