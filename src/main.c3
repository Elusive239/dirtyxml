import std::io;
import xml;


fn int main(String[] args)
{
	XMLDocument doc;
	defer doc.free();
	doc.load("test6.xml");
	io::printf("%s", doc);
	// doc.write("out_test6.xml");
	return 0;
}
