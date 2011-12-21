
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
		[Parameter]
		public SwitchParameter Refill { get; set; }
		[Parameter(ValueFromPipeline = true)]
		public PSObject InputObject { get; set; }
		[Parameter]
		public PSObject Filter
		{
			get { return _Filter; }
			set
			{
				_Filter = value;
				if (value != null)
				{
					_FilterHash = value.BaseObject as IDictionary;
					if (_FilterHash == null)
					{
						_FilterScript = value.BaseObject as ScriptBlock;
						if (_FilterScript == null)
							throw new PSArgumentException("Expected hashtable or script block.", "Filter");
					}
				}
			}
		}
		PSObject _Filter;
		IDictionary _FilterHash;
		ScriptBlock _FilterScript;
		readonly InitialSessionState _iss = InitialSessionState.CreateDefault();
		readonly Queue<PSObject> _queue = new Queue<PSObject>();
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
		protected override void StopProcessing()
		{
			Close(null);
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
Max queue  : {4}
Inner time : {5}
Total time : {6}
", _infoItemCount, _infoPartCount, _done.Count, _infoWaitCount, _infoMaxQueue, _infoTimeInner.Elapsed, _infoTimeTotal.Elapsed));

			try
			{
				// invoke End
				if (end != null && !Stopping)
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
			_isEnd = true;
			WriteVerbose(string.Format(null, "End: Items: {0}", _queue.Count));

			try
			{
				while (!Stopping && (_queue.Count > 0 || _work.Count > 0))
				{
					Take();
					if (_queue.Count > 0)
						Feed(true);
				}

				Close(_End);
			}
			catch
			{
				Close(null);
				throw;
			}
		}
		void Enqueue(PSObject value)
		{
			if (Filter != null)
			{
				if (_FilterHash != null)
				{
					if (_FilterHash.Contains(value.BaseObject))
						return;
					
					_FilterHash.Add(value, null);
				}
				else
				{
					if (!LanguagePrimitives.IsTrue(_FilterScript.InvokeReturnAsIs(value)))
						return;
				}
			}

			_queue.Enqueue(value);

			++_infoItemCount;
			if (_infoMaxQueue < _queue.Count)
				_infoMaxQueue = _queue.Count;
		}
		protected override void ProcessRecord()
		{
			Enqueue(InputObject);
			try
			{
				Take();

				while (_queue.Count >= Queue)
					Feed(true);

				if (_queue.Count >= Load)
					Feed(false);
			}
			catch
			{
				Close(null);
				throw;
			}
		}
		void WriteJob(Job job, ICollection<PSObject> result)
		{
			if (result != null && result.Count > 0)
			{
				if (Refill)
				{
					foreach (var it in result)
					{
						if (it != null)
						{
							var reference = it.BaseObject as PSReference;
							if (reference == null)
							{
								WriteObject(it);
							}
							else
							{
								++_infoItemCount;
								Enqueue(new PSObject(reference.Value));
							}
						}
					}
				}
				else
				{
					WriteObject(result, true);
				}
			}

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
		void Feed(bool force)
		{
			int ready;
			while (0 == (ready = Count - _work.Count))
			{
				if (!force)
					return;

				Wait();
				Take();
			}

			do
			{
				int part = Load;
				if (part > _queue.Count)
				{
					if (!_isEnd)
						return;

					part = _queue.Count;
				}

				// ensure the job node
				LinkedListNode<Job> node = _done.First;
				if (node == null)
				{
					node = new LinkedListNode<Job>(new Job(RunspaceFactory.CreateRunspace(_iss)));
					WriteJob(node.Value, node.Value.Begin(_Script, _Begin));
				}
				else
				{
					_done.RemoveFirst();
				}
				_work.AddLast(node);

				// feed the job
				++_infoPartCount;
				{
					_infoTimeInner.Start();
					node.Value.Feed(_queue, part);
					_infoTimeInner.Stop();
				}
			}
			while (--ready > 0 && _queue.Count > 0);
		}
		void Take()
		{
			bool done = false;
			var node = _work.First;
			while (node != null)
			{
				if (Stopping)
					return;

				if (node.Value.IsWorking)
				{
					if (Order)
						break;

					node = node.Next;
					continue;
				}

				// complete the job
				_infoTimeInner.Start();
				{
					done = true;
					var job = node.Value;
					WriteJob(job, job.Take());

					// move node, step next
					var next = node.Next;
					_work.Remove(node);
					_done.AddLast(node);
					node = next;
				}
				_infoTimeInner.Stop();
			}

			if (Auto && done)
				Tune();
		}
		void Tune()
		{
			if (_isEnd)
			{
				if (_queue.Count == 0)
					return;

				Load = _queue.Count / Count;
				if (Load * Count < _queue.Count)
					++Load;
				if (Load > Limit)
					Load = Limit;

				WriteVerbose(string.Format(null, "Work: {0}, Load: {1}, Queue: {2}", _work.Count, Load, _queue.Count));
				return;
			}

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
				WriteVerbose(string.Format(null, "Work: {0}, +Load: {1}, Cost: {2:p2}, Queue: {3}", _work.Count, Load, ratio, _queue.Count));
			}
			else if (ratio < MinCost)
			{
				var newLoad = (int)(Load * (1 - LoadDelta));
				if (newLoad == Load)
					--newLoad;
				if (newLoad < 1)
					newLoad = 1;

				Load = newLoad;
				WriteVerbose(string.Format(null, "Work: {0}, -Load: {1}, Cost: {2:p2}, Queue: {3}", _work.Count, Load, ratio, _queue.Count));
			}
		}
		void Wait()
		{
			++_infoWaitCount;

			if (Order)
			{
				_infoTimeInner.Start();
				{
					var node = _work.First;
					var job = node.Value;
					WriteJob(job, job.Take());
					_work.Remove(node);
					_done.AddLast(node);
				}
				_infoTimeInner.Stop();
				return;
			}

			var wait = new List<WaitHandle>(Count);
			foreach (var job in _work)
				wait.Add(job.Wait);

			WaitHandle.WaitAny(wait.ToArray());
		}
	}
}
