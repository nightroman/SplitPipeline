// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System;
using System.Management.Automation;

namespace SplitPipeline
{
	/// <summary>
	/// Pipeline helper methods exposed via the variable.
	/// </summary>
	public class Helper
	{
		/// <summary>
		/// Invokes the script with mutually exclusive lock.
		/// </summary>
		public object Lock(ScriptBlock script)
		{
			if (script == null) throw new ArgumentNullException("script");
			lock (this)
			{
				return script.InvokeReturnAsIs();
			}
		}
	}
}
