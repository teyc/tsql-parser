using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using TSQL.Tokens;

namespace TSQL.Elements
{
	public abstract class TSQLElement
	{
		class TokenCollection: Collection<TSQLToken>
		{
			protected override void InsertItem(int index, TSQLToken item)
			{
				if (item == null) throw new Exception("Must not insert nulls!");
			}

		}
		private readonly TokenCollection _tokens = new TokenCollection();

		public IList<TSQLToken> Tokens
		{
			get
			{
				return _tokens;
			}
		}

		public int BeginPosition
		{
			get
			{
				return Tokens.First().BeginPosition;
			}
		}

		public int EndPosition
		{
			get
			{
				return Tokens.Last().EndPosition;
			}
		}

		public int Length
		{
			get
			{
				return EndPosition - BeginPosition + 1;
			}
		}
	}
}
