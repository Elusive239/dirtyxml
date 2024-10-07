import std::io;
import xml;


fn int main(String[] args)
{
	const String FILE_PATH = "test.xml";
	XMLDocument doc;
	doc.load(FILE_PATH);
	doc.free();
	return 0;
}
