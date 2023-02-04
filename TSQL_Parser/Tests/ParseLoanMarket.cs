using NUnit.Framework;

using TSQL;
using TSQL.Statements;

namespace Tests
{
    [TestFixture(Category = "Expression Parsing")]
    public class ParseLoanMarket
    {

        private static string ReadEmbeddedResource(string path)
        {
            string resourceName = path.Replace("/", ".").Replace("\\", ".");
            System.Reflection.Assembly thisAssembly = typeof(ParseLoanMarket).Assembly;
            using (Stream stream = thisAssembly.GetManifestResourceStream(resourceName))
            using (StreamReader reader = new StreamReader(stream))
            {
                return reader.ReadToEnd();
            }
        }

        [Test]
        public void Parse_InsertSelect()
        {
            string sql = ReadEmbeddedResource("Tests/Scripts/InsertSelect.sql");
            var statements = TSQLStatementReader.ParseStatements(sql);

            foreach (TSQLInsertStatement statement in statements)
            {
                Console.Out.Write(String.Join(" ", statement.Tokens.Select(x => x.Text)));
            }
        }

        [Test]
        public void Parse_TypicalStoredProc()
        {
            var storedProc = ReadEmbeddedResource("Tests/Scripts/dbo.api_Contact_LoanList_MergedLead_Get.StoredProcedure.sql");

            List<TSQLStatement> statements = TSQLStatementReader.ParseStatements(storedProc,
                useQuotedIdentifiers: false, includeWhitespace: false);

            // int lastPos = 0;
            foreach (var statement in statements)
            {
                try
                {
                    Console.WriteLine("------------");
                    Console.WriteLine(storedProc.Substring(statement.BeginPosition, statement.Length));
                }
                catch (System.Exception)
                {

                    Console.WriteLine("xxxxxx");
                }
                WriteLineNumbers(storedProc, statement);
            }
        }

        [Test]
        public void ParseCase()
        {
            const string sql = @"SELECT ISNULL( CASE 1 WHEN 2 THEN 2 ELSE 3 END , '') FROM THETABLE";

            List<TSQLStatement> statements = TSQLStatementReader.ParseStatements(sql,
              useQuotedIdentifiers: false, includeWhitespace: true);

        }

        private void WriteLineNumbers(string storedProc, TSQLStatement statement)
        {
            Console.WriteLine("\nLine {0} to {1}",
                ToLineNumbers(statement.BeginPosition, storedProc),
                ToLineNumbers(statement.EndPosition, storedProc));
            foreach (var token in statement.Tokens)
            {
                Console.Write(token.Text + " ");
            }
        }

        int ToLineNumbers(int position, string data)
        {
            var part1 = data.Substring(0, position);
            return part1.Length - part1.Replace("\n", "").Length + 1;
        }
    }
}
