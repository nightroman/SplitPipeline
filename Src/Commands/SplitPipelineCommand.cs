
/*
Copyright (c) 2011-2012 Roman Kuzmin

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
using System.Diagnostics.CodeAnalysis;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Threading;

namespace SplitPipeline.Commands
{
	[Cmdlet(VerbsCommon.Split, "Pipeline")]
	public sealed class SplitPipelineCommand : PSCmdlet, IDisposable
	{
		[Parameter(Position = 0, Mandatory = true)]
		public ScriptBlock Script { get; set; }
		[Parameter]
		public ScriptBlock Begin { get; set; }
		[Parameter]
		public ScriptBlock End { get; set; }
		[Parameter]
		public ScriptBlock Finally { get; set; }
		[SuppressMessage("Microsoft.Performance", "CA1819:PropertiesShouldNotReturnArrays")]
		[Parameter]
		public string[] Variable { get; set; }
		[SuppressMessage("Microsoft.Performance", "CA1819:PropertiesShouldNotReturnArrays")]
		[Parameter]
		public string[] Function { get; set; }
		[SuppressMessage("Microsoft.Performance", "CA1819:PropertiesShouldNotReturnArrays")]
		[Parameter]
		public string[] Module { get; set; }
		[Parameter]
		public int Count { get; set; }
		[Parameter]
		public SwitchParameter Auto { get; set; }
		[Parameter]
		public SwitchParameter Order { get; set; }
		[Parameter]
		public SwitchParameter Refill { get; set; }
		[Parameter(ValueFromPipeline = true)]
		public PSObject InputObject { get; set; }
		[SuppressMessage("Microsoft.Design", "CA1062:Validate arguments of public methods", MessageId = "0")]
		[SuppressMessage("Microsoft.Performance", "CA1819:PropertiesShouldNotReturnArrays")]
		[Parameter]
		[ValidateCount(1, 2)]
		public int[] Load
		{
			get { return _Load; }
			set
			{
				if (value[0] < 1 || (value.Length == 2 && value[0] > value[1]))
					throw new PSArgumentException("Invalid load values.");

				_Load = value;
				MinLoad = value[0];
				if (value.Length == 2)
					MaxLoad = value[1];
			}
		}
		int[] _Load;
		int MinLoad = 1;
		int MaxLoad = int.MaxValue;
		int MaxQueue = int.MaxValue;
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
		string _Script, _Begin, _End, _Finally;
		bool _isEnd;
		int _currentLoad;
		int _infoItemCount;
		int _infoPartCount;
		int _infoWaitCount;
		int _infoMaxQueue;
		const double LoadDelta = 0.05;
		protected override void BeginProcessing()
		{
			_currentLoad = MinLoad;

			_Script = Script.ToString();
			if (Begin != null)
				_Begin = Begin.ToString();
			if (End != null)
				_End = End.ToString();
			if (Finally != null)
				_Finally = Finally.ToString();

			if (Count <= 0)
				Count = Environment.ProcessorCount;

			if (MaxLoad < int.MaxValue)
				MaxQueue = Count * MaxLoad;

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
		}
		[SuppressMessage("Microsoft.Design", "CA1031:DoNotCatchGeneralExceptionTypes")]
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
Total time : {5}
Items /sec : {6}
", _infoItemCount, _infoPartCount, _done.Count, _infoWaitCount, _infoMaxQueue, _infoTimeTotal.Elapsed, _infoItemCount / _infoTimeTotal.Elapsed.TotalSeconds));

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

			while (!Stopping && (_queue.Count > 0 || _work.Count > 0))
				Feed(true);

			Close(_End);
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
			if (_queue.Count < _currentLoad)
				return;

			while (_queue.Count >= MaxQueue)
				Feed(true);

			if (_queue.Count >= _currentLoad)
				Feed(false);
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
		[SuppressMessage("Microsoft.Reliability", "CA2000:Dispose objects before losing scope")]
		void Feed(bool force)
		{
			// try to make more pipes ready and more input in refill mode
			Take();

			// nothing to feed
			if (_queue.Count == 0)
				return;

			// count ready pipes
			int ready;
			while (0 == (ready = Count - _work.Count))
			{
				// no pipes, done if not forced
				if (!force)
					return;

				// wait for one or more pipes and make ready
				Wait();
				Take();
			}

			// part by the queue
			bool byQueue = false;
			if (Auto)
			{
				int partQueue = _queue.Count / Count;
				if (partQueue * Count < _queue.Count)
					++partQueue;
				if (partQueue > MaxLoad)
					partQueue = MaxLoad;
				else if (partQueue < MinLoad)
					partQueue = MinLoad;

				if (_isEnd || partQueue > _currentLoad)
				{
					byQueue = true;
					_currentLoad = partQueue;
					WriteVerbose(string.Format(null, "Work: {0}, *Load: {1}, Queue: {2}", _work.Count, _currentLoad, _queue.Count));
				}
			}

			do
			{
				int part = _currentLoad;
				if (part > _queue.Count)
				{
					if (!_isEnd && part >= _queue.Count + Count)
						break;
					part = _queue.Count;
				}

				// ensure the job node
				LinkedListNode<Job> node = _done.First;
				if (node == null)
				{
					node = new LinkedListNode<Job>(new Job(RunspaceFactory.CreateRunspace(_iss)));
					_work.AddLast(node);
					WriteJob(node.Value, node.Value.Begin(_Script, _Begin));
				}
				else
				{
					_done.RemoveFirst();
					_work.AddLast(node);
				}

				// feed the job
				++_infoPartCount;
				node.Value.Feed(_queue, part);
			}
			while (--ready > 0 && _queue.Count > 0);

			if (!Auto || byQueue || _infoPartCount <= Count)
				return;

			// not quite busy
			if (_queue.Count == 0)
			{
				var newLoad = (int)(_currentLoad * 1.5);
				if (newLoad == _currentLoad)
					++newLoad;
				if (newLoad > MaxLoad)
					newLoad = MaxLoad;

				_currentLoad = newLoad;
				WriteVerbose(string.Format(null, "Work: {0}, +Load: {1}, Queue: {2}", _work.Count, _currentLoad, _queue.Count));
			}
			else
			{
				WriteVerbose(string.Format(null, "Work: {0}, =Load: {1}, Queue: {2}", _work.Count, _currentLoad, _queue.Count));
			}
		}
		void Take()
		{
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
				var job = node.Value;
				WriteJob(job, job.Take());

				// move node, step next
				var next = node.Next;
				_work.Remove(node);
				_done.AddLast(node);
				node = next;
			}
		}
		void Wait()
		{
			++_infoWaitCount;

			if (Order)
			{
				var node = _work.First;
				var job = node.Value;
				WriteJob(job, job.Take());
				_work.Remove(node);
				_done.AddLast(node);
				return;
			}

			var wait = new List<WaitHandle>(Count);
			foreach (var job in _work)
				wait.Add(job.Wait);

			WaitHandle.WaitAny(wait.ToArray());
		}
		public void Dispose()
		{
			Close(null);
		}
	}
}
