
/*
Copyright (c) 2011 Roman Kuzmin

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Threading;

namespace SplitPipeline.Commands
{
	[Cmdlet(VerbsCommon.Split, "Pipeline")]
	public class SplitPipelineCommand : PSCmdlet
	{
		[Parameter(Position = 0, Mandatory = true)]
		public ScriptBlock Script { get; set; }
		[Parameter]
		public ScriptBlock Begin { get; set; }
		[Parameter]
		public ScriptBlock End { get; set; }
		[Parameter]
		public ScriptBlock Finally { get; set; }
		[System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Performance", "CA1819:PropertiesShouldNotReturnArrays"), Parameter]
		public string[] Variable { get; set; }
		[System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Performance", "CA1819:PropertiesShouldNotReturnArrays"), Parameter]
		public string[] Function { get; set; }
		[System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Performance", "CA1819:PropertiesShouldNotReturnArrays"), Parameter]
		public string[] Module { get; set; }
		[Parameter]
		public int Count { get; set; }
		[Parameter]
		public int Queue { get; set; }
		[Parameter]
		public int Load { get; set; }
		[Parameter]
		public int Limit { get; set; }
		[System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Performance", "CA1819:PropertiesShouldNotReturnArrays"), Parameter]
		[ValidateCount(1, 2)]
		public double[] Cost { get; set; }
		[Parameter]
		public SwitchParameter Auto { get; set; }
		[Parameter(ValueFromPipeline = true)]
		public PSObject InputObject { get; set; }
		readonly InitialSessionState _iss = InitialSessionState.CreateDefault();
		readonly Queue<PSObject> _input = new Queue<PSObject>();
		string _Script, _Begin, _End, _Finally;
		Job[] _jobs;
		int _infoItemCount;
		int _infoPartCount;
		int _infoPipeCount;
		int _infoWaitCount;
		int _infoMaxQueue;
		Stopwatch _infoTimeTotal = Stopwatch.StartNew();
		Stopwatch _infoTimeInner = new Stopwatch();
		long _lastInnerTicks;
		long _lastTotalTicks;
		double MaxCost = 0.05;
		double MinCost = 0.01;
		const double LoadDelta = 0.05;
		protected override void BeginProcessing()
		{
			if (Cost != null)
			{
				MaxCost = Cost[0] / 100;
				MinCost = Cost.Length > 1 ? Cost[1] / 100 : 0;
			}

			_Script = Script.ToString();
			if (Begin != null)
				_Begin = Begin.ToString();
			if (End != null)
				_End = End.ToString();
			if (Finally != null)
				_Finally = Finally.ToString();

			if (Count <= 0)
				Count = Environment.ProcessorCount;

			if (Load <= 0)
				Load = 1;

			if (Limit <= 0)
				Limit = int.MaxValue;
			else if (Limit < Load)
				Limit = Load;

			if (Queue <= 0)
				Queue = int.MaxValue;
			else if (Queue < Load)
				Queue = Load;

			if (Module != null)
				_iss.ImportPSModule(Module);

			if (Variable != null)
			{
				foreach (var name in Variable)
					_iss.Variables.Add(new SessionStateVariableEntry(name, GetVariableValue(name), string.Empty));
			}

			if (Function != null)
			{
				foreach (var name in Function)
				{
					var function = (FunctionInfo)SessionState.InvokeCommand.GetCommand(name, CommandTypes.Function);
					_iss.Commands.Add(new SessionStateFunctionEntry(name, function.Definition));
				}
			}

			_jobs = new Job[Count];

			_lastTotalTicks = _infoTimeTotal.ElapsedTicks;
		}
		[System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Design", "CA1031:DoNotCatchGeneralExceptionTypes")]
		void Close(string end)
		{
			if (_jobs == null)
				return;

			try
			{
				// end
				if (end != null)
				{
					foreach (var job in _jobs)
					{
						if (job != null)
							WriteJob(job, job.End(end));
					}
				}
			}
			finally
			{
				// finally
				if (_Finally != null)
				{
					var exceptions = new List<Exception>();
					foreach (var job in _jobs)
					{
						if (job != null)
						{
							try { job.Finally(_Finally); }
							catch (Exception e) { exceptions.Add(e); }
						}
					}

					foreach (var e in exceptions)
						WriteWarning("Exception in Finally: " + e.Message);
				}

				// close
				foreach (var job in _jobs)
					if (job != null)
						job.Close();

				_jobs = null;
			}

			WriteVerbose(string.Format(null, @"
Item count : {0}
Part count : {1}
Pipe count : {2}
Wait count : {3}
Load size  : {4}
Max queue  : {5}
Inner time : {6}
Total time : {7}
", _infoItemCount, _infoPartCount, _infoPipeCount, _infoWaitCount, Load, _infoMaxQueue,
 _infoTimeInner.Elapsed, _infoTimeTotal.Elapsed));
		}
		protected override void EndProcessing()
		{
			WriteVerbose(string.Format(null, "End: Items: {0}", _input.Count));
			try
			{
				Take(true);
				Close(_End);
			}
			catch
			{
				Close(null);
				throw;
			}
		}
		protected override void StopProcessing()
		{
			Close(null);
		}
		protected override void ProcessRecord()
		{
			_infoTimeInner.Start();
			++_infoItemCount;

			try
			{
				Take(false);

				_input.Enqueue(InputObject);
				if (_infoMaxQueue < _input.Count)
					_infoMaxQueue = _input.Count;

				if (_input.Count >= Queue)
				{
					do
					{
						Wait();
						Take(false);
						Feed();
					}
					while (_input.Count >= Queue);
				}
				else if (_input.Count >= Load)
				{
					Feed();
				}
			}
			catch
			{
				Close(null);
				throw;
			}

			_infoTimeInner.Stop();
		}
		void FeedJob(Job job, int count)
		{
			++_infoPartCount;
			job.Feed(_input, count);
		}
		void WriteJob(Job job, ICollection<PSObject> result)
		{
			if (result != null)
				WriteObject(result, true);

			var streams = job.Streams;
			if (streams.Verbose.Count > 0)
			{
				foreach (var record in streams.Verbose)
					WriteVerbose(record.Message);
				streams.Verbose.Clear();
			}

			if (streams.Warning.Count > 0)
			{
				foreach (var record in streams.Warning)
					WriteWarning(record.Message);
				streams.Warning.Clear();
			}

			if (streams.Error.Count > 0)
			{
				foreach (var record in streams.Error)
					WriteError(record);
				streams.Error.Clear();
			}
		}
		[System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Reliability", "CA2000:Dispose objects before losing scope")]
		void Feed()
		{
			int ready = 0;
			foreach (var job in _jobs)
				if (job == null || job.Done)
					++ready;

			if (ready == 0)
				return;

			int batch = _input.Count / ready;
			if (batch < Load)
				batch = Load;

			if (batch > Limit)
				batch = Limit;

			for (int i = 0; i < Count; ++i)
			{
				var job = _jobs[i];
				if (job == null)
				{
					++_infoPipeCount;

					bool timing = _infoTimeInner.IsRunning;
					if (timing)
						_infoTimeInner.Stop();

					job = new Job(RunspaceFactory.CreateRunspace(_iss));

					if (timing)
						_infoTimeInner.Start();

					var result = job.Begin(_Script, _Begin);
					if (_Begin != null)
						WriteJob(job, result);
					
					_jobs[i] = job;
				}
				else if (!job.Done)
				{
					continue;
				}

				// the last takes all
				--ready;
				if (ready == 0 && _input.Count < Limit)
					batch = _input.Count;
				if (batch > _input.Count)
					batch = _input.Count;

				FeedJob(job, batch);

				if (ready == 0 || _input.Count == 0)
					break;
			}
		}
		void Tune()
		{
			long innerTicks = _infoTimeInner.ElapsedTicks - _lastInnerTicks;
			long totalTicks = _infoTimeTotal.ElapsedTicks - _lastTotalTicks;
			_lastInnerTicks = _infoTimeInner.ElapsedTicks;
			_lastTotalTicks = _infoTimeTotal.ElapsedTicks;
			double ratio = (double)innerTicks / totalTicks;

			if (ratio > MaxCost)
			{
				var newLoad = (int)(Load * (1 + ratio));
				if (newLoad == Load)
					++newLoad;
				if (newLoad > Limit)
					newLoad = Limit;
				if (newLoad > Queue)
					newLoad = Queue;

				Load = newLoad;
				WriteVerbose(string.Format(null, "Pipes: {0}, Cost: {2:p2}, +Load: {1}", _infoPipeCount, Load, ratio));
			}
			else if (ratio < MinCost)
			{
				var newLoad = (int)(Load * (1 - LoadDelta));
				if (newLoad == Load)
					--newLoad;
				if (newLoad < 1)
					newLoad = 1;

				Load = newLoad;
				WriteVerbose(string.Format(null, "Pipes: {0}, Cost: {2:p2}, -Load: {1}", _infoPipeCount, Load, ratio));
			}
		}
		void Take(bool end)
		{
			for (; ; )
			{
				foreach (var job in _jobs)
				{
					if (job == null || job.Done)
						continue;

					if (!end)
					{
						var state = job.State;
						if (state != PSInvocationState.Completed && state != PSInvocationState.Failed)
							continue;
					}

					WriteJob(job, job.Take());
					if (Auto && !end)
						Tune();
				}

				if (!end || _input.Count == 0)
					break;

				Feed();
			}
		}
		void Wait()
		{
			++_infoWaitCount;

			var timing = _infoTimeInner.IsRunning;
			if (timing)
				_infoTimeInner.Stop();

			var wait = new List<WaitHandle>(Count);
			foreach (var job in _jobs)
				if (job != null)
					wait.Add(job.Wait);

			if (wait.Count > 0)
				WaitHandle.WaitAny(wait.ToArray());

			if (timing)
				_infoTimeInner.Start();
		}
	}
}
