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
    if(self.tag != null && self.tag.len() > 0) free(self.tag);
    if(self.inner_text != null  && self.inner_text.len() > 0) free(self.inner_text);
    // free(self);
}

fn XMLNode* new_node(XMLNode* parent){
    XMLNode* node   = calloc(XMLNode.sizeof);
    node.parent     = parent;
    node.tag        = "";
    node.inner_text = "";
    node.attributes.new_init();
    node.children.new_init();
    if (parent != null) parent.children.push(node);
    return node;
}

fn ZString XMLNode.find_attribute(XMLNode* node, ZString key){
    for(int i =0; i < node.attributes.len(); i++){
        io::printfn("Key: %s, Actual: %s", key, node.attributes[i].key);
        if(!compare_zstr(key, node.attributes[i].key)) return node.attributes[i].value;
    }
    return "";
}

fn int XMLDocument.load(XMLDocument* doc, String path){
    if(!file::is_file(path)){
        io::printfn("[INFO] File \"%s\" not found. Check your paths?", path);
        return 1;
    }
    char[] file = file::load_new(path)!!;
    // io::printfn("%s", file);    

    doc.root = new_node(null);

    char[256] lex;
    int lexi = 0;
    int i = 0;

    for(i; file[i] != '<'; ++i); //skip to first node
    XMLNode* current = doc.root;
    while(i < file.len){
        if(file[i] == '<'){
            lex[lexi] = '\0';
            //inner text
            if(lexi > 0){
                if(current == null){
                    io::printfn("[ERROR] Text outside of document.");
                    return 1;
                }

                current.inner_text = copy_zfa(&lex, lexi);
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
                if (compare_char_arr(current.tag, &lex, lexi)){
                    io::printfn("[ERROR] Mismatched tags (%s != %s)", current.tag, lex[0..lexi]);
                    return 1;
                }
                current = current.parent;
                i++;
                lexi = 0;
                continue;
            }

            //special nodes
            if(file[i+1] == '!' && file[i+2] == '-' && file[i+3] == '-'){
                while(file[i] != ' ' && file[i] != '>') lex[lexi++] = file[i++];
                lex[lexi] = '\0';

                if(!compare_char_arr("<!--", &lex, lexi)){
                    lex[lexi] = '\0';
                    while(!(file[i-2] == '-' && file[i-1] == '-' && file[i] == '>')){
                        lex[lexi++] = file[i++];
                        lex[lexi] = '\0';
                    }
                    continue;
                }
            }

            if(file[i+1] == '?'){
                while(file[i] != ' ' && file[i] != '>') lex[lexi++] = file[i++];
                lex[lexi] = '\0';
                if(!compare_char_arr("<?xml", &lex, lexi)){
                    lexi = 0;
                    XMLNode* desc = new_node(null);
                    int success = parse_attributes(&lex, &lexi, file, &i, desc);
                    if(success != 0){
                        return success;
                    }
                    doc.version = desc.find_attribute("version");
                    doc.encoding = desc.find_attribute("encoding");
                    desc.free();
                    continue;
                }
            }

            //set current node
            current = new_node(current);

            //start tag
            i++;
            int success = parse_attributes(&lex, &lexi, file, &i, current);
            if(success != 0){
                return success;
            }
            
            lex[lexi] = '\0';
            if( current.tag == null || current.tag.len() == 0){
                current.tag = copy_zfa(&lex, lexi);
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

fn int parse_attributes(char[] lex, int* xlexi, char[] file, int* xi, XMLNode* current){
    int i = *xi;
    int lexi = *xlexi;
    XMLAttribute* current_attribute;
    while(file[i] != '>'){
        lex[lexi++] = file[i++];
        //tag name
        if(file[i] == ' ' && current.tag.len() == 0){
            lex[lexi] = '\0';
            current.tag = copy_zfa(lex, lexi);
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
            current_attribute = calloc(XMLAttribute.sizeof);
            lex[lexi] = '\0';
            // current_attribute.key = (ZString) lex[0..lexi];
            current_attribute.key = copy_zfa(lex, lexi);
            // io::printfn("Attribute Lex: %s, Key: %s, Size: %d", (ZString) lex[0..lexi], current_attribute.key, lexi);
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
            current_attribute.value = copy_zfa(lex, lexi);
            // io::printfn("Attribute: %s=\"%s\"", current_attribute.key, current_attribute.value);
            current.attributes.push(current_attribute);
            current_attribute = null;
            lexi = 0;
            i++;
            continue;
        }
    }
    *xi = i;
    *xlexi = lexi;
    return 0;
}

macro ZString copy_zfa(char[] arr, int len) {
    ZString zstr = null;
    zstr = (ZString) calloc(len*char.sizeof);
    for(int i = 0; i < len; ++i){
        zstr[i] = arr[ i];
    }
    return zstr;
}

macro ZString copy_zfz(ZString arr) {
    ZString zstr = (ZString) calloc(arr.len()*char.sizeof);
    for(int i = 0; (i) < arr.len(); i++){
        zstr[i] = arr[ i];
    }
    return zstr;
}

macro bool compare_char_arr(ZString tag, char[] buffer, int len){
    if(tag.len() != len) return true;
    for(int i = 0; i < len; i++){
        if(tag[i] - buffer[i] != 0){
            return true;
        }
    }
    return false;
}

macro bool compare_zstr(ZString a, ZString b){
    if(a.len() != b.len()) return true;
    for(int i = 0; i < a.len(); i++){
        if(a[i] - b[i] != 0){
            return true;
        }
    }
    return false;
}
