### sample python interface - pagerank

from ctypes import *

### load gunrock shared library - libgunrock
gunrock = cdll.LoadLibrary('../build/lib/libgunrock.so')
### read in input CSR arrays from files

labels_file = "../dataset/small/stars_2total_separate"
datatest = open(labels_file, "r")

line = datatest.readline()
(labels_no, dim) = line.split()

#print("line: ", line)
#print("number of lines ", labels_no)
#print("dimension ", dim)
#array = [[int(x) for x in line.split()] for line in datatest]
#print(array)

datatest.close()

### input data
labels = labels_file.encode('utf-8')
k = 5
epsilon = 1
min_pts = 1

### output data
clusters = pointer((c_int * int(labels_no))())
clusters_counter = pointer(c_int(0))
core_points_counter = pointer(c_int(0))
noise_points_counter = pointer(c_int(0))

print ('run gunrock snn')
### call gunrock function on device
elapsed = gunrock.snn(labels, k, epsilon, min_pts, clusters, clusters_counter, core_points_counter, noise_points_counter)

### sample results
print ('elapsed: ' + str(elapsed))
