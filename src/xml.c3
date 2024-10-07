module xml;
import std::io;
import std::collections;
import std::io::path;

struct XMLDocument
{
    XMLNode* root;
    ZString version;
    ZString encoding;
}

struct XMLAttribute
{
    ZString key;
    ZString value;
}

struct XMLNode
{
    ZString tag;
    ZString inner_text;
    XMLNode* parent;
    XMLAttributeList attributes;
    XMLNodeList children;
}

enum TagType
{
    TAG_START,
    TAG_INLINE
}

//decided to use C3s built in lists!
def XMLAttributeList = List(<XMLAttribute*>);
def XMLNodeList = List(<XMLNode*>);

//Functions


fn void XMLDocument.free(&self){
    if(self.encoding != null) free(self.encoding);
    if(self.version != null) free(self.version);
    if(self.root != null) self.root.free();
    free(self);
}

fn void XMLNode.free(&self){
    if(self.parent != null) self.parent.free();
    self.attributes.free();
    self.children.free();
    if(self.tag != null) free(self.tag);
    if(self.inner_text != null) free(self.inner_text);
    free(self);
}

fn int XMLDocument.load(XMLDocument* doc, String path){
    if(!file::is_file(path)){
        io::printfn("[INFO] File \"%s\" not found. Check your paths?", path);
        return 1;
    }
    char[] file = file::load_new(path)!!;
    io::printfn("%s", file);    

    doc.root = new_node(null);

    char[256] lex;
    int lexi = 0;
    int i = 0;

    XMLNode* current;
    while(i < file.len){
        if(file[i] == '<'){
            lex[lexi] = '\0';
            //inner text
            if(lexi > 0){
                if(current == null){
                    io::printfn("[ERROR] Text outside of document.");
                    return 1;
                }

                current.inner_text = from_char_array(&lex, lexi);
                lexi = 0;
            }
            
            //end of tag
            if(file[i+1] == '/'){
                i+=2;
                while(file[i] != '>'){
                    lex[lexi++] = file[i++];
                }
                lex[lexi] = '\0';
                if(current == null){
                    io::printfn("[ERROR] Already at the root!" );
                    return 1;
                }
                if (compare_tags(current.tag, &lex, lexi)){
                    io::printfn("[ERROR] Mismatched tags (%s != %s)", current.tag, lex[0..lexi]);
                    return 1;
                }
                current = current.parent;
                i++;
                continue;
            }

            //set current node
            if(current == null){
                current = doc.root;
            }else{
                current = new_node(current);
            }

            //get tag name
            i++;
            while(file[i] != '>'){
                lex[lexi++] = file[i++];
            }
            lex[lexi] = '\0';
            current.tag = from_char_array(&lex, lexi);
            lexi = 0;
            i++;
            continue;
        }
        else {
            // i++;
            lex[lexi++] = file[i++];
        }
    }
    io::printfn("root: %s", doc.root.inner_text);
    io::printfn("root: %s", doc.root.tag);
    io::printfn("child: %s", doc.root.children.get(0).inner_text);
    io::printfn("child: %s", doc.root.children.get(0).tag);
    return 0;
}

fn XMLNode* new_node(XMLNode* parent){
    XMLNode* node = malloc(XMLNode.sizeof);
    node.parent = parent;
    node.tag = "";
    node.inner_text = "";
    node.attributes.new_init();
    node.children.new_init();
    if (parent != null) parent.children.push_front(node);
    return node;
}

macro ZString from_char_array(char[] arr, int len) {
    ZString zstr = (ZString) calloc(len*char.sizeof);
    for(int c = 0; c < len; c++){
        zstr[c] = arr[c];
    }
    return zstr;
}

macro bool compare_tags(ZString tag, char[] buffer, int len){
    if(tag.len() > len) return true;
    for(int i = 0; i < len; i++){
        if(tag[i] - buffer[i] != 0){
            return true;
        }
    }
    return false;
}