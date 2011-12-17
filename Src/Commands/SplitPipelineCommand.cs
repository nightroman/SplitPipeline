
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
		[Parameter]
		public SwitchParameter Order { get; set; }
		[Parameter(ValueFromPipeline = true)]
		public PSObject InputObject { get; set; }
		readonly InitialSessionState _iss = InitialSessionState.CreateDefault();
		readonly Queue<PSObject> _input = new Queue<PSObject>();
		readonly LinkedList<Job> _done = new LinkedList<Job>();
		readonly LinkedList<Job> _work = new LinkedList<Job>();
		readonly Stopwatch _infoTimeTotal = Stopwatch.StartNew();
		readonly Stopwatch _infoTimeInner = new Stopwatch();
		string _Script, _Begin, _End, _Finally;
		bool _isEnd;
		int _infoItemCount;
		int _infoPartCount;
		int _infoWaitCount;
		int _infoMaxQueue;
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

			_lastTotalTicks = _infoTimeTotal.ElapsedTicks;
		}
		[System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Design", "CA1031:DoNotCatchGeneralExceptionTypes")]
		void Close(string end)
		{
			// move jobs to done
			while (_work.Count > 0)
			{
				var node = _work.First;
				_work.RemoveFirst();
				_done.AddLast(node);
			}

			// closed?
			if (_done.Count == 0)
				return;

			// show info
			WriteVerbose(string.Format(null, @"
Item count : {0}
Part count : {1}
Pipe count : {2}
Wait count : {3}
Load size  : {4}
Max queue  : {5}
Inner time : {6}
Total time : {7}
", _infoItemCount, _infoPartCount, _done.Count, _infoWaitCount, Load, _infoMaxQueue,
 _infoTimeInner.Elapsed, _infoTimeTotal.Elapsed));

			try
			{
				// invoke End
				if (end != null)
				{
					foreach (var job in _done)
						WriteJob(job, job.End(end));
				}
			}
			finally
			{
				// invoke Finally
				if (_Finally != null)
				{
					var exceptions = new List<Exception>();
					foreach (var job in _done)
					{
						try { job.Finally(_Finally); }
						catch (Exception e) { exceptions.Add(e); }
					}

					foreach (var e in exceptions)
						WriteWarning("Exception in Finally: " + e.Message);
				}

				// close
				foreach (var job in _done)
					job.Close();

				_done.Clear();
			}
		}
		protected override void EndProcessing()
		{
			WriteVerbose(string.Format(null, "End: Items: {0}", _input.Count));
			_isEnd = true;

			try
			{
				Take();
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
				Take();

				_input.Enqueue(InputObject);
				if (_infoMaxQueue < _input.Count)
					_infoMaxQueue = _input.Count;

				while (_input.Count >= Queue)
				{
					if (_work.Count > 0)
					{
						Wait();
						Take();
					}

					Feed();
				}

				if (_input.Count >= Load)
					Feed();
			}
			catch
			{
				Close(null);
				throw;
			}

			_infoTimeInner.Stop();
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
			int ready = Count - _work.Count;
			if (ready == 0)
				return;

			int part = _input.Count / ready;
			if (part < Load)
				part = Load;

			if (part > Limit)
				part = Limit;

			do
			{
				// the last takes all
				--ready;
				if (ready == 0 && _input.Count <= Limit)
					part = _input.Count;
				if (part > _input.Count)
					part = _input.Count;

				// ensure the job node
				LinkedListNode<Job> node = _done.First;
				if (node == null)
				{
					bool timing = _infoTimeInner.IsRunning;
					if (timing)
						_infoTimeInner.Stop();

					node = new LinkedListNode<Job>(new Job(RunspaceFactory.CreateRunspace(_iss)));

					var result = node.Value.Begin(_Script, _Begin);
					if (_Begin != null)
						WriteJob(node.Value, result);
					
					if (timing)
						_infoTimeInner.Start();
				}
				else
				{
					_done.RemoveFirst();
				}
				_work.AddLast(node);

				// feed the job
				++_infoPartCount;
				node.Value.Feed(_input, part);
			}
			while (ready > 0 && _input.Count > 0);
		}
		void Take()
		{
			bool done = false;
			for (; ; )
			{
				var node = _work.First;
				while (node != null)
				{
					if (_isEnd)
					{
						if (Stopping)
							return;
					}
					else
					{
						if (node.Value.IsWorking)
						{
							if (Order)
								break;

							node = node.Next;
							continue;
						}
					}

					var next = node.Next;
					_work.Remove(node);
					_done.AddLast(node);

					WriteJob(node.Value, node.Value.Take());
					node = next;
					done = true;
				}

				if (!_isEnd || _input.Count == 0 || Stopping)
					break;

				Feed();
			}
			
			if (Auto && done && !_isEnd)
				Tune();
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
				WriteVerbose(string.Format(null, "Pipes: {0}, Cost: {2:p2}, +Load: {1}", _done.Count + _work.Count, Load, ratio));
			}
			else if (ratio < MinCost)
			{
				var newLoad = (int)(Load * (1 - LoadDelta));
				if (newLoad == Load)
					--newLoad;
				if (newLoad < 1)
					newLoad = 1;

				Load = newLoad;
				WriteVerbose(string.Format(null, "Pipes: {0}, Cost: {2:p2}, -Load: {1}", _done.Count + _work.Count, Load, ratio));
			}
		}
		void Wait()
		{
			++_infoWaitCount;

			if (Order)
			{
				var node = _work.First;
				WriteJob(node.Value, node.Value.Take());
				_work.Remove(node);
				_done.AddLast(node);
				return;
			}

			var timing = _infoTimeInner.IsRunning;
			if (timing)
				_infoTimeInner.Stop();

			var wait = new List<WaitHandle>(Count);
			foreach (var job in _work)
				wait.Add(job.Wait);

			WaitHandle.WaitAny(wait.ToArray());

			if (timing)
				_infoTimeInner.Start();
		}
	}
}
