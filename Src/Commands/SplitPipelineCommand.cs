
/*
Copyright (c) 2011-2014 Roman Kuzmin

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
		[Parameter]
		public string[] Variable { get; set; }
		[Parameter]
		public string[] Function { get; set; }
		[Parameter]
		public string[] Module { get; set; }
		[Parameter]
		public int Count { get; set; }
		[Parameter]
		public SwitchParameter Order { get; set; }
		[Parameter]
		public SwitchParameter Refill { get; set; }
		[Parameter(ValueFromPipeline = true)]
		public PSObject InputObject { get; set; }
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
		[Parameter]
		public ApartmentState ApartmentState
		{
			get { return _iss.ApartmentState; }
			set { _iss.ApartmentState = value; }
		}

		PSObject _Filter;
		IDictionary _FilterHash;
		ScriptBlock _FilterScript;
		readonly InitialSessionState _iss = InitialSessionState.CreateDefault();
		readonly Queue<PSObject> _queue = new Queue<PSObject>();
		readonly LinkedList<Job> _done = new LinkedList<Job>();
		readonly LinkedList<Job> _work = new LinkedList<Job>();
		readonly Stopwatch _infoTimeTotal = Stopwatch.StartNew();
		readonly object _syncObject = new object();
		string _Script, _Begin, _End, _Finally;
		bool xStop;
		bool _isEnd;
		bool _closed;
		bool _verbose;
		int _currentLoad;
		int _infoItemCount;
		int _infoPartCount;
		int _infoWaitCount;
		int _infoMaxQueue;

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

			object parameter;
			if (MyInvocation.BoundParameters.TryGetValue("Verbose", out parameter))
				_verbose = ((SwitchParameter)parameter).ToBool();
			else
				_verbose = (ActionPreference)GetVariableValue("VerbosePreference") != ActionPreference.SilentlyContinue;
		}
		protected override void ProcessRecord()
		{
			try
			{
				Enqueue(InputObject);

				if (xStop || _queue.Count < _currentLoad)
					return;

				while (!xStop && _queue.Count >= MaxQueue)
					Feed(true);

				if (!xStop && _queue.Count >= _currentLoad)
					Feed(false);
			}
			catch
			{
				if (!xStop)
					throw;
			}
		}
		protected override void EndProcessing()
		{
			try
			{
				_isEnd = true;

				if (_verbose)
					WriteVerbose(string.Format(null, "Split-Pipeline: End, Queue = {0}", _queue.Count));

				while (!xStop && (_queue.Count > 0 || _work.Count > 0))
					Feed(true);

				Close(_End);
			}
			catch
			{
				if (!xStop)
					throw;
			}
		}
		protected override void StopProcessing()
		{
			xStop = true;
			Close(null);
		}
		public void Dispose()
		{
			if (!_closed)
				Close(null);
		}
		new void WriteDebug(string value)
		{
			//! may throw on stopping
			try
			{
				base.WriteDebug(value);
			}
			catch
			{
				if (!xStop)
					throw;
			}
		}
		new void WriteError(ErrorRecord value)
		{
			//! may throw on stopping
			try
			{
				base.WriteError(value);
			}
			catch
			{
				if (!xStop)
					throw;
			}
		}
		new void WriteObject(object value)
		{
			//! may throw on stopping
			try
			{
				base.WriteObject(value);
			}
			catch
			{
				if (!xStop)
					throw;
			}
		}
		new void WriteVerbose(string value)
		{
			//! may throw on stopping
			try
			{
				if (!xStop)
					base.WriteVerbose(value);
			}
			catch
			{
				if (!xStop)
					throw;
			}
		}
		new void WriteWarning(string value)
		{
			//! may throw on stopping
			try
			{
				base.WriteWarning(value);
			}
			catch
			{
				if (!xStop)
					throw;
			}
		}

		/// <summary>
		/// Puts the object to the input queue unless it is filtered out.
		/// Callers must check the maximum queue count.
		/// </summary>
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
		/// <summary>
		/// Gets the next part of input items and feeds them to a ready job.
		/// If forced it waits for a ready job.
		/// </summary>
		void Feed(bool force)
		{
			// try to make more jobs ready and more input available in refill mode
			Take();

			// no input? check this after taking, refill adds input on taking
			if (_queue.Count == 0)
				return;

			// ready jobs?
			while (Count - _work.Count == 0)
			{
				// no ready jobs, done if not forced
				if (!force)
					return;

				// wait for jobs and make them ready
				Wait();
				Take();
			}

			// split the queue equally between all potential jobs
			int load = _queue.Count / Count;
			if (load * Count < _queue.Count)
				++load;

			// correct by limits
			if (load > MaxLoad)
				load = MaxLoad;
			else if (load < MinLoad)
				load = MinLoad;

			// store the last
			_currentLoad = load;

			lock (_syncObject)
			{
				int nReadyJob = Count - _work.Count;
				if (xStop || nReadyJob == 0)
					return;

				do
				{
					// limit load by the queue
					if (load > _queue.Count)
					{
						load = _queue.Count;

						// if load is less than minimum then stop feeding if it's not the end
						if (load < MinLoad && !_isEnd)
							return;
					}

					// ensure the job node
					LinkedListNode<Job> node = _done.First;
					if (node == null)
					{
						node = new LinkedListNode<Job>(new Job(RunspaceFactory.CreateRunspace(_iss)));
						_work.AddLast(node);
						Write(node.Value, node.Value.InvokeBegin(_Begin, _Script));
					}
					else
					{
						_done.RemoveFirst();
						_work.AddLast(node);
					}

					if (xStop)
						return;

					// feed info
					if (_verbose)
						WriteVerbose(string.Format(null, "Split-Pipeline: Jobs = {0}; Load = {1}; Queue = {2}", _work.Count, load, _queue.Count));

					// feed the job
					++_infoPartCount;
					node.Value.BeginInvoke(_queue, load);
				}
				while (!xStop && --nReadyJob > 0 && _queue.Count > 0);
			}
		}
		/// <summary>
		/// Finds finished jobs, writes their output, moves them to done.
		/// If ordered stops on the first found working job, it has to finish.
		/// </summary>
		void Take()
		{
			lock (_syncObject)
			{
				var node = _work.First;
				while (node != null)
				{
					if (node.Value.IsWorking)
					{
						if (Order)
							break;

						node = node.Next;
						continue;
					}

					// complete the job
					var job = node.Value;
					if (xStop)
						return;
					Write(job, job.EndInvoke());

					// move node, step next
					var next = node.Next;
					_work.Remove(node);
					_done.AddLast(node);
					node = next;
				}
			}
		}
		/// <summary>
		/// Waits for any job to finish. If ordered then its the first job in the queue.
		/// </summary>
		void Wait()
		{
			var wait = new List<WaitHandle>(Count);

			lock (_syncObject)
			{
				++_infoWaitCount;

				if (Order)
				{
					var node = _work.First;
					var job = node.Value;
					Write(job, job.EndInvoke());
					_work.Remove(node);
					_done.AddLast(node);
					return;
				}

				foreach (var job in _work)
					wait.Add(job.WaitHandle);
			}

			//! #3: here it used to hang
			WaitHandle.WaitAny(wait.ToArray());
		}
		/// <summary>
		/// Writes job output objects and propagates streams.
		/// Moves refilling objects from output to the queue.
		/// </summary>
		void Write(Job job, ICollection<PSObject> output)
		{
			if (output != null && output.Count > 0)
			{
				if (Refill)
				{
					foreach (var it in output)
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
					WriteObject(output, true);
				}
			}

			var streams = job.Streams;

			if (streams.Debug.Count > 0)
			{
				foreach (var record in streams.Debug)
					WriteDebug(record.Message);
				streams.Debug.Clear();
			}

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
		/// <summary>
		/// Moves all jobs to done then for each jobs:
		/// -- calls the end script on ending;
		/// -- calls the finally script always;
		/// -- closes the job.
		/// </summary>
		void Close(string end)
		{
			lock (_syncObject)
			{
				// close once
				if (_closed)
					return;
				_closed = true;

				// move jobs to done
				while (_work.Count > 0)
				{
					var node = _work.First;
					_work.RemoveFirst();
					_done.AddLast(node);
				}

				// done?
				if (_done.Count == 0)
					return;

				try
				{
					// summary
					if (_isEnd && _verbose)
						WriteVerbose(string.Format(null, @"Split-Pipeline:
Item count = {0}
Part count = {1}
Pipe count = {2}
Wait count = {3}
Max queue  = {4}
Total time = {5}
Items /sec = {6}
", _infoItemCount, _infoPartCount, _done.Count, _infoWaitCount, _infoMaxQueue, _infoTimeTotal.Elapsed, _infoItemCount / _infoTimeTotal.Elapsed.TotalSeconds));

					// invoke the end script on ending, if any
					if (!xStop && end != null)
					{
						foreach (var job in _done)
							Write(job, job.InvokeEnd(end));
					}
				}
				finally
				{
					// invoke the finally script always, do not throw, closing is ahead
					if (_Finally != null)
					{
						// let them all to work
						var exceptions = new List<Exception>();
						foreach (var job in _done)
						{
							try
							{
								job.InvokeFinally(_Finally);
							}
							catch (Exception e)
							{
								exceptions.Add(e);
							}
						}

						// then write errors as warnings
						if (!xStop && exceptions.Count > 0)
						{
							try
							{
								foreach (var e in exceptions)
									WriteWarning("Exception in Finally: " + e.Message);
							}
							catch (RuntimeException)
							{ }
						}
					}

					// close jobs
					foreach (var job in _done)
						job.Close();
					_done.Clear();
				}
			}
		}
	}
}
