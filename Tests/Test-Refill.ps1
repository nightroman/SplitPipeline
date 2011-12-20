
<#
.Synopsis
	Tests Split-Pipeline -Refill and compares with the alternative method.

.Description
	This is an example of Split-Pipeline with refilled input. The convention is
	simple: [ref] objects refill the input, other objects go to output as usual.

	This test processes hierarchical data using two methods:
	1) Split-Pipeline - parallel processing and refilled input;
	2) Step-Node - sequential recursive stepping through nodes.

	Both methods simulate slow data request on a node $_ as:

		Start-Sleep -Milliseconds 500; $_.GetEnumerator()

	Both methods process/output leaf nodes in the same way:

		'{0}={1}' -f $node.Key, $node.Value

	Split-Pipeline refills the input with container nodes:

		[ref]$node.Value

	Step-Node calls itself recursively with container nodes:

		Step-Node $node.Value

	The test shows that sorted results of two methods are the same and
	Split-Pipeline normally works faster than Step-Node.

	Result order is different due to different order of node processing.
	Besides, order of Split-Pipeline results is not necessarily constant.
#>

### Hierarchical data: container nodes are represented by hashtables
$node1 = @{data1=1; data2=2; data3=3}
$node2 = @{node1=$node1; node2=$node1; data4=4; data5=5}
$root = @{node1=$node2; node2=$node2; data6=6; data7=7}
$root | Format-Custom | Out-String

### Test 1: Refill Split-Pipeline with nodes
$time1 = [Diagnostics.Stopwatch]::StartNew()
$data1 = $root | Split-Pipeline -Refill {process{
	foreach($node in $(Start-Sleep -Milliseconds 500; $_.GetEnumerator())) {
		if ($node.Value -is [hashtable]) {
			[ref]$node.Value
		}
		else {
			'{0}={1}' -f $node.Key, $node.Value
		}
	}
}}
$time1.Stop()

### Test 2: Step through nodes recursively
$time2 = [Diagnostics.Stopwatch]::StartNew()
function Step-Node($_) {
	foreach($node in $(Start-Sleep -Milliseconds 500; $_.GetEnumerator())) {
		if ($node.Value -is [hashtable]) {
			Step-Node $node.Value
		}
		else {
			'{0}={1}' -f $node.Key, $node.Value
		}
	}
}
$data2 = Step-Node $root
$time2.Stop()

### Test: Sorted results should be the same
$data1 = ($data1 | Sort-Object) -join ','
$data2 = ($data2 | Sort-Object) -join ','
$data1
$data2
if ($data1 -ne $data2) { throw 'Different results' }

### Test: Split-Pipeline should work faster than recursive processing
$time1.Elapsed.ToString()
$time2.Elapsed.ToString()
if ($time1.Elapsed -ge $time2.Elapsed) { Write-Warning 'Unexpected times.' }
