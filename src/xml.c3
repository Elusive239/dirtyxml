module xml;
import std::io;
import std::collections;

struct _XMLDocument
{
    XMLNode* root;
    ZString version;
    ZString encoding;
}

struct _XMLAttribute
{
    ZString key;
    ZString value;
}

struct _XMLNode
{
    ZString tag;
    ZString inner_text;
    _XMLNode* parent;
    XMLAttributeList attributes;
    XMLNodeList children;
}

enum _TagType
{
    TAG_START,
    TAG_INLINE
}

def TagType = _TagType;

def XMLDocument = _XMLDocument;
def XMLAttribute = _XMLAttribute;
def XMLAttributeList = List(<XMLAttribute>);
def XMLNode = _XMLNode;
def XMLNodeList = List(<XMLNode>);

fn int XMLDocument.load(XMLDocument* doc, String path){
    if(!file::is_file(path)){
        io::printfn("[INFO] File \"%s\" not found. Check your paths?", path);
        return 1;
    }

    char[] file = file::load_new(path)!!;
    io::printfn("%s\n", file);
    return 0;
}