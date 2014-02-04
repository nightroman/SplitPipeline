
<#
.Synopsis
	Tests Split-Pipeline -Load.

.Link
	Invoked by https://github.com/nightroman/Invoke-Build
#>

Import-Module SplitPipeline
Set-StrictMode -Version Latest

task Error {
	# 0 args
	$e = @'
Cannot validate argument on parameter 'Load'. *Specify more than 1 arguments and then try the command again.
'@
	$$ = try { 1..9 | Split-Pipeline {} -Load @() } catch { $_ }
	assert ("$$" -clike $e)
	$$ = try { 1..9 | Split-Pipeline {} -Load $null } catch { $_ }
	assert ("$$" -clike $e)

	# 3+ args
	$$ = try { 1..9 | Split-Pipeline {} -Load 1,2,3 } catch { $_ }
	assert ("$$" -clike @'
Cannot validate argument on parameter 'Load'. *exceeds the maximum number of allowed arguments (2)*
'@)

	# [0] > [1]
	$$ = try { 1..9 | Split-Pipeline {} -Load 1,0 } catch { $_ }
	assert ("$$" -ceq @'
Cannot bind parameter 'Load' to the target. Exception setting "Load": "Load maximum must be greater or equal to minimum."
'@)

	# [0]<1 is fine and treated as omitted, [1] is ignored
	$r = 1..9 | Split-Pipeline {@($input).Count} -Load 0,-1 -Count 2
	assert ($r.Count -eq 2)
	assert ($r[0] -eq 5)
	assert ($r[1] -eq 4)
}

# v1.4.0 By default the whole input is collected and split evenly
task TheWholeInput {
	$r = 1..11 | Split-Pipeline -Count 2 {@($input).Count}
	$r
	assert ($r.Count -eq 2)
	assert ($r[0] -eq 6)
	assert ($r[1] -eq 5)
}

# `-Load 1` lets the algorithm to work as soon as any input available
task LetItChoose {
	$r = 1..11 | Split-Pipeline -Count 2 {@($input).Count} -Load 1
	$r
	assert ($r.Count -ge 4)
	assert ($r[0] -eq 1)
	assert ($r[1] -eq 1)
	assert (($r | Measure-Object -Sum).Sum -eq 11)
}

# `-Load 2` sets the minimum
task Min2MaxX {
	$r = 1..11 | Split-Pipeline -Count 2 {@($input).Count} -Load 2
	$r
	assert ($r.Count -ge 4)
	assert ($r[0] -eq 2)
	assert ($r[1] -eq 2)
	assert (($r | Measure-Object -Sum).Sum -eq 11)
}

# `-Load 4,4` sets the part size to 4
task Min4Max4 {
	$r = 1..11 | Split-Pipeline -Count 2 {@($input).Count} -Load 4,4 -Order
	$r
	assert ($r.Count -eq 3)
	assert ($r[0] -eq 4)
	assert ($r[1] -eq 4)
	assert ($r[2] -eq 3)
}
