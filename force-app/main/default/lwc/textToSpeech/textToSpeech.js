import { LightningElement, api, track } from 'lwc';

export default class TextToSpeech extends LightningElement {
    @api 
    get text() {
        return this._text;
    }
    set text(value) {
        this._text = value;
        this.showSpeaker = value && value.trim().length > 0;
    }
    _text = '';
    @track isPlaying = false;
    @track showSpeaker = false;
    speechSynthesis = window.speechSynthesis;
    currentSpeech = null;

    get speakerIcon() {
        return this.isPlaying ? 'utility:stop' : 'utility:play';
    }

    get speakerButtonClass() {
        return `speaker-button ${this.isPlaying ? 'playing' : ''}`;
    }

    get speakerTitle() {
        return this.isPlaying ? 'Stop' : 'Play';
    }

    handleSpeak() {
        if (!this.text || !this.speechSynthesis) return;

        if (this.isPlaying) {
            // Stop speaking
            this.speechSynthesis.cancel();
            this.isPlaying = false;
            this.currentSpeech = null;
        } else {
            // Start speaking
            const utterance = new SpeechSynthesisUtterance(this.text);
            
            utterance.onend = () => {
                this.isPlaying = false;
                this.currentSpeech = null;
            };

            utterance.onerror = (event) => {
                console.error('Speech synthesis error:', event);
                this.isPlaying = false;
                this.currentSpeech = null;
            };

            this.currentSpeech = utterance;
            this.isPlaying = true;
            this.speechSynthesis.speak(utterance);
        }
    }

    disconnectedCallback() {
        if (this.currentSpeech) {
            this.speechSynthesis.cancel();
        }
    }
} 