module xml_test;
import std::io;
import xml;

fn int main(String[] args)
{
	XMLDocument doc;
	doc.load("text.xml");
	return 0;
}
