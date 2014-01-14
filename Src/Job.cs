
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
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Threading;

namespace SplitPipeline
{
	class Job
	{
		readonly PowerShell _posh = PowerShell.Create();
		PSDataCollection<PSObject> _input;
		IAsyncResult _async;
		
		/// <summary>
		/// Gets the pipeline streams.
		/// </summary>
		public PSDataStreams Streams { get { return _posh.Streams; } }
		/// <summary>
		/// Gets the wait handle of the async pipeline.
		/// </summary>
		public WaitHandle WaitHandle { get { return _async.AsyncWaitHandle; } }
		/// <summary>
		/// Gets true if it is not completed or failed.
		/// </summary>
		public bool IsWorking
		{
			get
			{
				switch (_posh.InvocationStateInfo.State)
				{
					case PSInvocationState.Completed: return false;
					case PSInvocationState.Failed: return false;
				}
				return true;
			}
		}
		/// <summary>
		/// New job with its runspace. The runspace gets opened.
		/// </summary>
		public Job(Runspace runspace)
		{
			_posh.Runspace = runspace;
			runspace.Open();
		}
		/// <summary>
		/// Invokes the begin script, if any, sets the pipeline script once, returns the begin output.
		/// </summary>
		public Collection<PSObject> InvokeBegin(string begin, string script)
		{
			Collection<PSObject> result = null;
			if (begin != null)
			{
				_posh.AddScript(begin, false);
				result = _posh.Invoke();
				_posh.Commands.Clear();
			}

			_posh.AddScript(script);
			return result;
		}
		/// <summary>
		/// Starts the pipeline script async.
		/// </summary>
		public void BeginInvoke(Queue<PSObject> input, int count)
		{
			_input = new PSDataCollection<PSObject>(count);
			while (--count >= 0)
				_input.Add(input.Dequeue());
			_input.Complete();

			_async = _posh.BeginInvoke(_input);
		}
		/// <summary>
		/// Waits for the pipeline to finish and returns its output.
		/// </summary>
		/// <returns></returns>
		public PSDataCollection<PSObject> EndInvoke()
		{
			try
			{
				if (_async == null)
					return null;

				return _posh.EndInvoke(_async);
			}
			finally
			{
				_input = null;
			}
		}
		/// <summary>
		/// Invokes the end script and returns its output.
		/// </summary>
		public Collection<PSObject> InvokeEnd(string script)
		{
			_posh.Commands.Clear();
			_posh.AddScript(script, false);
			return _posh.Invoke();
		}
		/// <summary>
		/// Invokes the final script, its output is ignored.
		/// </summary>
		public void InvokeFinally(string script)
		{
			// it may be still running, e.g. on stopping
			if (_posh.InvocationStateInfo.State == PSInvocationState.Running)
				_posh.Stop();

			// invoke 
			_posh.Commands.Clear();
			_posh.AddScript(script, false);
			_posh.Invoke();
		}
		/// <summary>
		/// Closes the pipeline and the runspace.
		/// </summary>
		public void Close()
		{
			_posh.Dispose();
			_posh.Runspace.Dispose();
		}
	}
}
