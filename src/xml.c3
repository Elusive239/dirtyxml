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
}

fn void XMLNode.free(&self){
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
                // io::printfn("lex contents: %s", lex[0..lexi]);
                continue;
            }

            //set current node
            if(current == null){
                io::printfn("Node is Root");
                current = doc.root;
            }else{
                io::printfn("Node is not Root");
                current = new_node(current);
            }

            //start tag
            i++;
            XMLAttribute* current_attribute = calloc(XMLAttribute.sizeof);
            while(file[i] != '>'){
                lex[lexi++] = file[i++];
                
                //tag name
                if(file[i] == ' ' && (current.tag.len() == 0)){
                    lex[lexi] = '\0';
                    current.tag = from_char_array(&lex, lexi);
                    lexi = 0;
                    i++;
                    continue;
                }
                //ignore spaces (usually)
                else if(lex[lexi-1] == ' '){
                    lexi--;
                    continue;
                }
                //attribute key
                else if(file[i] == '='){
                    lex[lexi] = '\0';
                    current_attribute.key = from_char_array(&lex, lexi);
                    lexi = 0;
                    continue;
                }
                //attribute value
                else if(file[i] == '\"'){
                    if(current_attribute.key == null){
                        io::printfn("[ERROR] Value has no key.");
                        return 1;
                    }
                    lexi = 0;
                    i++;
                    while(file[i] != '\"'){
                        lex[lexi++] = file[i++];
                    }
                    lex[lexi] = '\0';
                    current_attribute.value = from_char_array(&lex, lexi);
                    current.attributes.push(current_attribute);
                    current_attribute = null;
                    lexi = 0;
                    i++;
                    continue;
                }
            }
            lex[lexi] = '\0';
            if(current.tag.len() == 0 || current.tag == null){
                current.tag = from_char_array(&lex, lexi);
            }
            lexi = 0;
            i++;
            continue;
        }
        else {
            // i++;
            lex[lexi++] = file[i++];
        }
    }
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
    // io::printfn("Buffer contents: %s", buffer[0..len]);
    // io::printfn("Tag contents: %s", tag);
    if(tag.len() > len) return true;
    for(int i = 0; i < len; i++){
        if(tag[i] - buffer[i] != 0){
            return true;
        }
    }
    return false;
}
