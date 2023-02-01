using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

using NUnit.Framework;

using TSQL;
using TSQL.Tokens;

using Tests.Properties;
using Tests.Tokens;
using TSQL.Statements;

namespace Tests
{
    [TestFixture(Category = "Expression Parsing")]
    public class ParseLoanMarket
    {
        private readonly string _storedProc;
		private readonly System.Reflection.Assembly thisAssembly = typeof(ParseLoanMarket).Assembly;

        public ParseLoanMarket()
        {
            using (Stream stream = thisAssembly.GetManifestResourceStream("Tests.Scripts.dbo.api_Contact_LoanList_MergedLead_Get.StoredProcedure.sql"))
            using (StreamReader reader = new StreamReader(stream))
            {
                _storedProc = reader.ReadToEnd();
            }

        }

		[Test]
		public void Parse_InsertSelect()
		{
			using (Stream stream = thisAssembly.GetManifestResourceStream("Tests.Scripts.InsertSelect.sql"))
			using (StreamReader reader = new StreamReader(stream))
			{
				var sql = reader.ReadToEnd();
				var statements = TSQLStatementReader.ParseStatements(sql);

				foreach (TSQLInsertStatement statement in statements)
				{
					Console.Out.Write(String.Join(" ", statement.Tokens.Select(x => x.Text)));
				}
			}
		}

        [Test]
        public void Parse_TypicalStoredProc()
        {
            using (StringReader reader = new StringReader(_storedProc))
            using (TSQLTokenizer lexer = new TSQLTokenizer(reader) { IncludeWhitespace = true, UseQuotedIdentifiers = false })
            {
                Assert.IsTrue(lexer.IncludeWhitespace);
            }

            List<TSQLStatement> statements = TSQLStatementReader.ParseStatements(_storedProc, useQuotedIdentifiers: false, includeWhitespace: true);
			foreach (var statement in statements)
			{

			}
        }
    }
}
