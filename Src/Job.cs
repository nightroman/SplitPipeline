
/*
Copyright (c) 2011-2013 Roman Kuzmin

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
		IAsyncResult _result;
		public PSDataStreams Streams { get { return _posh.Streams; } }
		public WaitHandle Wait { get { return _result.AsyncWaitHandle; } }
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
		public Job(Runspace runspace)
		{
			_posh.Runspace = runspace;
			runspace.Open();
		}
		public Collection<PSObject> Begin(string script, string begin)
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
		public Collection<PSObject> End(string script)
		{
			_posh.Commands.Clear();
			_posh.AddScript(script, false);
			return _posh.Invoke();
		}
		public void Finally(string script)
		{
			_posh.Commands.Clear();
			_posh.AddScript(script, false);
			_posh.Invoke();
		}
		public void Feed(Queue<PSObject> input, int count)
		{
			_input = new PSDataCollection<PSObject>(count);
			while (--count >= 0)
				_input.Add(input.Dequeue());
			_input.Complete();

			_result = _posh.BeginInvoke(_input);
		}
		public PSDataCollection<PSObject> Take()
		{
			try
			{
				if (_result == null)
					return null;

				return _posh.EndInvoke(_result);
			}
			finally
			{
				_input = null;
			}
		}
		public void Close()
		{
			if (_posh.InvocationStateInfo.State == PSInvocationState.Running)
				_posh.Stop();

			_posh.Runspace.Dispose();
			_posh.Dispose();
		}
	}
}
