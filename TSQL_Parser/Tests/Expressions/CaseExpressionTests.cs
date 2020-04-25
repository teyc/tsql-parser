﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using NUnit.Framework;

using TSQL;
using TSQL.Expressions;
using TSQL.Statements;
using TSQL.Tokens;

using Tests.Tokens;

namespace Tests.Expressions
{
	[TestFixture(Category = "Expression Parsing")]
	public class CaseExpressionTests
	{
		[Test]
		public void CaseExpression_Dont_Overrun()
		{
			List<TSQLStatement> statements = TSQLStatementReader.ParseStatements(
				@"
					BEGIN
						SELECT CASE WHEN 1 = 2 THEN 0 ELSE 1 END
					END",
				includeWhitespace: false);

			Assert.AreEqual(3, statements.Count);
			Assert.AreEqual(1, statements[0].Tokens.Count);

			TokenComparisons.CompareTokenLists(
				new List<TSQLToken>()
					{
						new TSQLKeyword(20, "SELECT"),
						new TSQLKeyword(27, "CASE"),
						new TSQLKeyword(32, "WHEN"),
						new TSQLNumericLiteral(37, "1"),
						new TSQLOperator(39, "="),
						new TSQLNumericLiteral(41, "2"),
						new TSQLKeyword(43, "THEN"),
						new TSQLNumericLiteral(48, "0"),
						new TSQLKeyword(50, "ELSE"),
						new TSQLNumericLiteral(55, "1"),
						new TSQLKeyword(57, "END")
					},
				statements[1].Tokens);

			Assert.AreEqual(1, statements[2].Tokens.Count);
			Assert.IsTrue(statements[2].Tokens[0].IsKeyword(TSQLKeywords.END));
		}

		[Test]
		public void CaseExpression_Regression_Duplicated_Case()
		{
			List<TSQLStatement> statements = TSQLStatementReader.ParseStatements(
				@"select case when abi = '03654' then 0 else 1 end as abi;",
				includeWhitespace: false);

			Assert.AreEqual(1, statements.Count);

			List<TSQLToken> tokens = statements[0].Tokens;

			TokenComparisons.CompareTokenLists(
				new List<TSQLToken>()
					{
						new TSQLKeyword(0, "select"),
						new TSQLKeyword(7, "case"),
						new TSQLKeyword(12, "when"),
						new TSQLIdentifier(17, "abi"),
						new TSQLOperator(21, "="),
						new TSQLStringLiteral(23, "'03654'"),
						new TSQLKeyword(31, "then"),
						new TSQLNumericLiteral(36, "0"),
						new TSQLKeyword(38, "else"),
						new TSQLNumericLiteral(43, "1"),
						new TSQLKeyword(45, "end"),
						new TSQLKeyword(49, "as"),
						new TSQLIdentifier(52, "abi")
					},
				tokens);
		}
	}
}
