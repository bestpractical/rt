import { ClassicEditor } from '@ckeditor/ckeditor5-editor-classic';
import Plugin from '@ckeditor/ckeditor5-core/src/plugin';
import { ListDropdownItemDefinition } from '@ckeditor/ckeditor5-ui/src/dropdown/utils';
import { ButtonView, createDropdown, addListToDropdown, DropdownButtonView, Model } from 'ckeditor5/src/ui';
import Collection from '@ckeditor/ckeditor5-utils/src/collection';
import { Alignment } from '@ckeditor/ckeditor5-alignment';
import { Autoformat } from '@ckeditor/ckeditor5-autoformat';
import { Writer } from '@ckeditor/ckeditor5-engine'; // Import Writer from CKEditor
import {
    Bold,
    Code,
    Italic,
    Strikethrough,
    Subscript,
    Superscript
} from '@ckeditor/ckeditor5-basic-styles';
import { BlockQuote } from '@ckeditor/ckeditor5-block-quote';
import { CodeBlock } from '@ckeditor/ckeditor5-code-block';
import { Essentials } from '@ckeditor/ckeditor5-essentials';
import { FontBackgroundColor, FontColor, FontFamily, FontSize } from '@ckeditor/ckeditor5-font';
import { Heading } from '@ckeditor/ckeditor5-heading';
import {
    Image,
    ImageCaption,
    ImageStyle,
    ImageToolbar,
    ImageUpload
} from '@ckeditor/ckeditor5-image';
import { Indent, IndentBlock } from '@ckeditor/ckeditor5-indent';
import { Link } from '@ckeditor/ckeditor5-link';
import { List, TodoList } from '@ckeditor/ckeditor5-list';
import { MediaEmbed } from '@ckeditor/ckeditor5-media-embed';
import { Paragraph } from '@ckeditor/ckeditor5-paragraph';
import { PasteFromOffice } from '@ckeditor/ckeditor5-paste-from-office';
import { SourceEditing } from '@ckeditor/ckeditor5-source-editing';
import { Table, TableToolbar } from '@ckeditor/ckeditor5-table';
import { TextTransformation } from '@ckeditor/ckeditor5-typing';
import { Undo } from '@ckeditor/ckeditor5-undo';
import { Base64UploadAdapter } from '@ckeditor/ckeditor5-upload';
import type { EditorConfig } from '@ckeditor/ckeditor5-core';

interface responseData {
suggestion: string;
}
let isShowAutoComplete = false;
let prevLen = 0;
const popupLabels: { [key: string]: string } = {
  adjustTone: "Adjust Tone",
  aisuggestion: "AI Suggestion",
  translate: "Translate"
};
let gptResponse: string = '';

/**
 * Function loadModal call the internal API for getting the HTML to load on the screen.
 * @param rawText Editor text to display on the screen.
 * @param optionType Type of popup to render on the screen.
 * @returns JSON containing HTML to render on screen.
 */
async function loadModal(rawText: string = 'Default text', optionType: string = 'aisuggestion') {
    let url = `/Helpers/OpenAiSuggestion/aiModal`;
    try {
        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: new URLSearchParams({ rawText: rawText, callType: optionType, popupLabel: popupLabels[optionType] }).toString()
        });

        // Parse the response as plain text (HTML)
        const data = await response.text();

        // Return the HTML data
        return data;

    } catch (error) {
        console.error('Error:', error);
        return "Error occurred while fetching the HTML content.";
    }
}

/**
 * The function fetchAiResults call the internal API, which further call the chatgpt API interface,
 * to get the appropiate result, for the request.
 * @param conversationInput Actual text from popup.
 * @param optionType Type of request
 * @param translateFrom In case of translation (translate from language)
 * @param translateTo In case of translation (translate to language)
 * @returns Response from the AI.
 */
async function fetchAiResults(conversationInput: string, optionType: string = 'aisuggestion', translateFrom='', translateTo=''): Promise<string> {
    let url = `/Helpers/OpenAiSuggestion/aisuggestion`;
    try {
        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: new URLSearchParams({ rawText: conversationInput, callType: optionType, transFrom:translateFrom, transTo:translateTo }).toString()
        });

        // Parse the response as JSON
        const data = await response.json();

        // Check if 'suggestion' exists in the response and return it
        return data?.suggestion || "I'm unable to find the file.";

    } catch (error) {
        console.error('Error:', error);
        return "Error occurred while fetching the suggestion.";
    }
}

/**
 * The function fetchAutocompleteSuggestion call the AI to fetch the next few words to autocomple the statement.
 * @param conversationInput The text user writinig on the editor.
 * @returns Predicted text from AI.
 */
async function fetchAutocompleteSuggestion(conversationInput: string): Promise<string> {
    let url = `/Helpers/OpenAiSuggestion/aisuggestion`;
    try {
        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: new URLSearchParams({ rawText: conversationInput, callType: 'autocomplete' }).toString()
        });
        const data = await response.json();
        // Handle null or undefined suggestion with default as an empty string
        // prefixing a " " to avoid conactenation to text
        let suggestion = data?.suggestion ? ` ${data.suggestion}` : "";
        return suggestion;
        // return data?.suggestion || "";
    } catch (error) {
        console.error('Error fetching autocomplete suggestion:', error);
        return "";
    }
}

/**
 * Function showAutocompletePlaceholder will render the auto-complete text on editor.
 * @param editor CKeditor object
 * @param suggestion Suggestion from AI
 */
function showAutocompletePlaceholder(editor: any, suggestion: any){
    editor.model.change((viewWriter: any) => {
        const selection = editor.model.document.selection;
        const range = selection.getFirstRange(); // Get the current selection range

        // Remove any existing autocomplete placeholder marker
        if (editor.model.markers.has('autocompleteSuggestion')) {
            viewWriter.removeMarker('autocompleteSuggestion');
            console.log("removed marker.....");
        }

        // Create a marker for the autocomplete suggestion at the current cursor position
        viewWriter.addMarker('autocompleteSuggestion', {
            range,
            usingOperation: false,
            affectsData: false
        });
    });

    insertPlaceholderWithTab(editor, suggestion);
}

/**
 * Function insertPlaceholderWithTab take the user action of pressing tab to take the predicted auto-complete
 *  text and make it actual text on the editor. 
 * @param editor CKeditor object
 * @param suggestion Suggestion from AI
 */
function insertPlaceholderWithTab(editor: any, suggestion: string) {
    // Dynamically add the CSS for grayed-out placeholder text
    const style = document.createElement('style');
    style.innerHTML = `
        .placeholder-autocomplete-text {
            color: gray;
            opacity: 0.5;
        }
    `;
    document.head.appendChild(style);

    // Declare placeholderText and placeholderElement within the function scope
    let placeholderText = suggestion;
    let placeholderElement: any = null;

    // Insert the placeholder text visually in the view layer
    editor.editing.view.change((viewWriter: any) => {
        const viewRoot = editor.editing.view.document.getRoot();
        const selection = editor.model.document.selection;

        // Create and insert the placeholder as a styled inline element in the view
        const placeholderViewText = viewWriter.createText(placeholderText);
        placeholderElement = viewWriter.createContainerElement('span', {
            class: 'placeholder-autocomplete-text'
        });

        // Insert placeholder at the current selection position in the view
        const viewPosition = editor.editing.mapper.toViewPosition(selection.getFirstPosition());
        viewWriter.insert(viewPosition, placeholderElement);
        viewWriter.insert(viewWriter.createPositionAt(placeholderElement, 0), placeholderViewText);

        // Store reference to the placeholder element
        placeholderElement = placeholderElement;
        console.log('Inserted placeholder:', placeholderText);
    });

    // Listen for Tab key to replace the placeholder visually and in the model
    editor.keystrokes.set('Tab', (event: KeyboardEvent, cancel: Function) => {
        console.log('Tab key pressed');

        if (placeholderElement) {
            console.log('Placeholder reference found on Tab press');
            console.log('Replacing placeholder with text:', placeholderText);

            // Insert suggestion text into the model layer at the current cursor position
            editor.model.change((writer: any) => {
                const position = editor.model.document.selection.getFirstPosition();

                // Insert the placeholder text at the current position
                writer.insertText(placeholderText, position);

                // Move the cursor directly after the inserted text
                const newPosition = writer.createPositionAt(position.parent, position.offset + placeholderText.length);
                writer.setSelection(newPosition);

                // Log detailed information about the newPosition
                console.log('Text inserted and cursor moved to:');
                console.log('Path:', newPosition.path);
                console.log('Offset:', newPosition.offset);
                console.log('Root name:', newPosition.root.rootName);

                // Clear placeholderText after insertion
                placeholderText = "";  // Reset the placeholderText after insertion
                editor.editing.view.change((viewWriter: any) => {
                    viewWriter.remove(placeholderElement);  // Remove from the view
                    console.log("Removing existing placeholder from view...");
                });
            });
            cancel();
        }
    });
    
    // Handle click inside the editor to reset the placeholder
    editor.ui.view.editable.element.addEventListener('click', (event: MouseEvent) => {
        placeholderText = "";
        if (placeholderElement) {
            editor.editing.view.change((viewWriter: any) => {
                viewWriter.remove(placeholderElement);
            });
            placeholderElement = null;
        }
    });

    // Handle click outside the editor to reset the placeholder
    document.addEventListener('click', (event) => {
        const editorElement = editor.ui.view.editable.element;
        if (!editorElement.contains(event.target as Node)) {
            placeholderText = "";
            if (placeholderElement) {
                editor.editing.view.change((viewWriter: any) => {
                    viewWriter.remove(placeholderElement);
                });
                placeholderElement = null;
            }
        }
    });

    // Remove placeholder when typing continuously
    editor.model.document.on('change:data', () => {
        if (placeholderElement) {
            editor.editing.view.change((viewWriter: any) => {
                viewWriter.remove(placeholderElement);  // Remove placeholder on any new typing
                console.log("Removing placeholder due to typing...");
            });
            placeholderElement = null;  // Reset placeholder reference
        }
    });
}


/**
 * Helper function to strip the HTML from the string.
 * @param html HTML in form of text.
 * @returns Stripped text from HTML.
 */
function stripHTML(html: string): string {
    const tempDiv = document.createElement("div");
    tempDiv.innerHTML = html;
    return tempDiv.textContent || tempDiv.innerText || "";
}

/**
 * AI Suggestion Plugin class for AI drop down.
 */
class AiSuggestionPlugin extends Plugin {
    init() {

    const editor = this.editor;
    console.log('AI Suggestion Plugin is initialized!');

    let debounceTimeout: any;
    let isAppending = false;

    editor.model.document.on('change:data', async () => {
        clearTimeout(debounceTimeout); // Clear previous timeout if there's any

        debounceTimeout = setTimeout(async () => {
            if (isAppending) {
                // Skip processing if content was just appended by autocomplete
                isAppending = false;
                return;
            }

            // getting editor text without HTML elements
            const currentText = stripHTML(editor.data.get().trim()); // Get current editor content and trim whitespace
            const selection = editor.model.document.selection;
            const range = selection.getRanges().next().value;
            const pathSecondIndex = range.start.path[1];

            // console.log("range"+ range +" pathSecondIndex "+pathSecondIndex);
            // console.log("currentText"+ currentText.toString()+" length "+ currentText.length);

            if (!currentText || currentText.split(/\s+/).length === 1 || pathSecondIndex < currentText.length) {
                console.log("returned");
                return;
            }

            const suggestion = await fetchAutocompleteSuggestion(currentText);
            if (suggestion) {
                showAutocompletePlaceholder(editor, suggestion);
                isAppending = true;
            }

        }, 500); // 1 second debounce
    });


        // Create a dropdown with multiple AI suggestions
        editor.ui.componentFactory.add('aiSuggestion', locale => {
        
        	const style = document.createElement('style');
	    style.type = 'text/css';
	    style.innerHTML = `
		.ck.ck-dropdown__button:focus .button:focus {
		    outline: none !important;
		    box-shadow: none !important;
		    background-color: transparent !important;
		}
		.button:focus {
		background-color: transparent !important;
		}
	    `;
	    document.head.appendChild(style);
            const dropdownItems = new Collection<ListDropdownItemDefinition>();

            // Add multiple options to the dropdown
            dropdownItems.add({
                type: 'button',
                model: new Model({
                    label: 'Adjust tone/voice',
                    withText: true,
                    id: 'adjustTone',
                    tooltip: 'Adjust tone/voice'
                })
            });

            dropdownItems.add({
                type: 'button',
                model: new Model({
                    label: 'AI Suggestion',
                    withText: true,
                    id: 'aisuggestion',
                    tooltip: 'AI Suggestion'
                })
            });

            dropdownItems.add({
                type: 'button',
                model: new Model({
                    label: 'Translate',
                    withText: true,
                    id: 'translate',
                    tooltip: 'Translate'
                })
            });

            // Create the dropdown view
            const dropdownView = createDropdown(locale, DropdownButtonView);

            // Populate the dropdown with the list of options
            addListToDropdown(dropdownView, dropdownItems);

            dropdownView.buttonView.set({
                label: 'AI Suggestions',
                tooltip: true,
                withText: true
            });

            // Event handling for dropdown option execution
            dropdownView.on('execute', async (eventInfo) => {
                const { id, label } = eventInfo.source as Model;
                // ----selection part start----
                let isSelectedText = false;
                let selectedText = '';

                const selection = editor.model.document.selection;
                console.log('selection:', selection);

                if (!selection.isCollapsed) {
                    const range = selection.getFirstRange();
                    if (range) {

                        // Iterate over the items in the range
                        for (const item of range.getItems()) {
                            if (item.is('$textProxy')) {
                                // Concatenate the text data from text nodes
                                selectedText += item.data;
                            }
                        }

			            isSelectedText = true;
                        console.log(selectedText);
                    } else {
                        console.log('No selection');
                    }
                }
                let editorContent = !isSelectedText ? editor.data.get() : selectedText;
                // ----selection part end----

                createSuggestionModal(editorContent, editor, id as string, isSelectedText);
            });

            return dropdownView;
        });
    }
}

/**
 * Function extractParagraphsWithRegex() will extract the text from the HTML to render on the modal.
 * @param input API Response
 * @returns formatted text
 */
function extractParagraphsWithRegex(input: string): string {
    // Match all the text inside <p> tags
    const regex = /<p[^>]*>(.*?)<\/p>/g;
    const paragraphs: string[] = [];
    let match;

    // Loop through all matches and extract the content inside <p> tags
    while ((match = regex.exec(input)) !== null) {
        const text = match[1].replace(/<[^>]*>/g, '').trim(); // Remove any inner HTML tags and trim
        if (text) {
            paragraphs.push(text);
        }
    }
    return paragraphs.join("\n");
}

/**
 * The function createSuggestionModal will create the container for the popup HTML getting from the internal
 * API, this will render the HTML popup.
 * @param editorContent Text from the editor
 * @param editor Editor object
 * @param optionType Type of popup
 * @param isSelectedText In case text is selected from the editor.
 */
function createSuggestionModal(editorContent: string, editor: any, optionType: string = 'aisuggestion', isSelectedText: boolean = false){
    if (!isSelectedText) {
        editorContent = extractParagraphsWithRegex(editorContent);
    }

    loadModal(editorContent, optionType).then(data => {
        // Create overlay container
        const overlay = document.createElement('div');
        overlay.style.position = 'fixed';
        overlay.style.top = '0';
        overlay.style.left = '0';
        overlay.style.width = '100%';
        overlay.style.height = '100%';
        overlay.style.backgroundColor = 'rgba(0, 0, 0, 0.7)';
        overlay.style.zIndex = '999';
        overlay.style.display = 'flex';
        overlay.style.justifyContent = 'center';
        overlay.style.alignItems = 'center';

        // Create inner container for HTML content
        const contentContainer = document.createElement('div');
        contentContainer.style.position = 'relative';
        contentContainer.style.zIndex = '1000';
        contentContainer.style.backgroundColor = '#fff';
        contentContainer.style.padding = '20px';
        contentContainer.style.borderRadius = '8px';
        contentContainer.style.maxWidth = '80%';
        contentContainer.style.maxHeight = '80%';
        contentContainer.style.overflowY = 'auto';

        // Insert the fetched HTML content into the container
        contentContainer.innerHTML = data;

        // Append the content container to the overlay
        overlay.appendChild(contentContainer);
        document.body.appendChild(overlay);

        // Close modal function
        const closeModal = () => {
            document.body.removeChild(overlay);
        };

        // Attach event listeners to buttons within the modal content
        const generateButton = contentContainer.querySelector('#generateButton');
        const doneButton = contentContainer.querySelector('#doneButton');
        const cancelButton = contentContainer.querySelector('#cancelButton');
        const editorText = contentContainer.querySelector('#textArea1') as HTMLTextAreaElement | null;
        const suggestionText = contentContainer.querySelector('#textArea2') as HTMLTextAreaElement | null;
	const loadingSpinner = contentContainer.querySelector('#loadingSpinner') as HTMLElement | null;
	const translateFrom = contentContainer.querySelector('#translateFrom') as HTMLInputElement | null;
	const translateTo = contentContainer.querySelector('#translateTo') as HTMLInputElement | null;
	const translateFromElem = contentContainer.querySelector('#translateFromElem') as HTMLElement | null;
	const translateToElem = contentContainer.querySelector('#translateToElem') as HTMLElement | null;
	
	if(optionType== 'translate') {
	translateFromElem.style.display = "block";
	translateToElem.style.display = "block";
	} else {
	translateFromElem.style.display = "none";
	translateToElem.style.display = "none";
	}

        if (generateButton) {
            generateButton.addEventListener('click', async () => {
                if (editorText && suggestionText) {
                    let response: string | undefined;

                    if (optionType === 'adjustTone') {
                        console.log('Adjusting tone/voice');
                        if(loadingSpinner) {
                        	loadingSpinner.style.display = "block";
                        }
                        response = await fetchAiResults(editorText.value, optionType);
                    } else if (optionType === 'aisuggestion') {
                        console.log('AI Suggestion');
                        if(loadingSpinner) {
                        	loadingSpinner.style.display = "block";
                        }
                        response = await fetchAiResults(editorText.value, optionType);
                    } else if (optionType === 'translate') {
                        console.log('Translate', translateFrom.value, translateTo.value);
                        if(loadingSpinner) {
                        	loadingSpinner.style.display = "block";
                        }
                        response = await fetchAiResults(editorText.value, optionType, translateFrom.value, translateTo.value);
                    }

                    console.log('response is :', response);
                    if (response) {
                    if(loadingSpinner) {
                        	loadingSpinner.style.display = "none";
                        }
                        gptResponse = response;
                        suggestionText.value = extractParagraphsWithRegex(response);; // Update suggestionText with the API response
                        suggestionText.innerHTML =  extractParagraphsWithRegex(response);;
                    }
                    console.log('element val', suggestionText.value);

                } else {
                    console.error('editorText is not found');
                }
            });
        }



if (doneButton) {
    doneButton.addEventListener('click', () => {
        if (suggestionText) {
            const aiResponse = gptResponse; // Capture the AI response
            //const aiResponse = suggestionText.value; // Capture the AI response
            editor.model.change((writer: Writer) => {
                // Convert the response HTML to model content using the CKEditor data processor
                const viewFragment = editor.data.processor.toView(aiResponse);
                const modelFragment = editor.data.toModel(viewFragment);
                // Insert the model content at the editor's selection or replace the entire content if no selection
                const selection = editor.model.document.selection;
                if (!selection.isCollapsed) {
                    editor.model.insertContent(modelFragment, selection);
                } else {
                    // Replace the entire editor content if there's no selection
                    editor.data.set(aiResponse);
                }
            });
        } else {
            console.error('suggestionText is not found');
        }
        closeModal(); // Close the modal
    });
}

        if (cancelButton) {
            cancelButton.addEventListener('click', () => {
                closeModal();
            });
        }

    }).catch(error => {
        console.error('Error fetching HTML content:', error);
    });
}

class Editor extends ClassicEditor {
    public static override builtinPlugins = [
        Alignment,
        Autoformat,
        Base64UploadAdapter,
        BlockQuote,
        Bold,
        Code,
        CodeBlock,
        Essentials,
        FontBackgroundColor,
        FontColor,
        FontFamily,
        FontSize,
        Heading,
        Image,
        ImageCaption,
        ImageStyle,
        ImageToolbar,
        ImageUpload,
        Indent,
        IndentBlock,
        Italic,
        Link,
        List,
        MediaEmbed,
        Paragraph,
        PasteFromOffice,
        SourceEditing,
        Strikethrough,
        Subscript,
        Superscript,
        Table,
        TableToolbar,
        TextTransformation,
        TodoList,
        Undo,
        AiSuggestionPlugin // Add the custom plugin here
    ];

    public static override defaultConfig: EditorConfig = {
        toolbar: {
            items: [
                'undo',                'redo',        '|',            'heading',
                '|',                   'fontfamily',  'fontsize',     'fontColor',
                'fontBackgroundColor', '|',           'bold',         'italic',
                'strikethrough',       'subscript',   'superscript',  '|',
                'link',                'imageUpload', 'mediaEmbed',   '|',
                'code',                'blockQuote',  'codeBlock',    '|',
                'insertTable',         'alignment',   '|',            'bulletedList',
                'numberedList',        'todoList',    '|',            'outdent',
                'indent',              '|',           'sourceEditing',  'aiSuggestion'
            ]
        },
        language: 'en',
        image: {
            toolbar: [
                'imageTextAlternative',
                'toggleImageCaption',
                'imageStyle:inline',
                'imageStyle:block',
                'imageStyle:side'
            ]
        },
        table: {
            contentToolbar: [
                'tableColumn',
                'tableRow',
                'mergeTableCells'
            ]
        },
        mediaEmbed: {
            removeProviders: [ 'instagram', 'twitter', 'googleMaps', 'flickr', 'facebook' ],
            previewsInData: true
        }
    };
}

export default Editor;
