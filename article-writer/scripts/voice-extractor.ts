#!/usr/bin/env bun
/**
 * Voice Extractor for Article Writer
 * 
 * Extracts speaking patterns, phrases, and style from multi-speaker transcriptions.
 * Outputs data compatible with authors.json for enhancing author profiles.
 */

import { parseArgs } from "util";
import { readFileSync, writeFileSync, existsSync } from "fs";
import { join } from "path";

interface Turn {
  speaker: string;
  text: string;
}

interface VoiceAnalysis {
  extracted_from: string[];
  sample_count: number;
  total_words: number;
  sentence_structure: {
    avg_length: number;
    variety: string;
    question_ratio: number;
  };
  communication_style: Array<{ trait: string; percentage: number }>;
  characteristic_expressions: string[];
  sentence_starters: string[];
  signature_vocabulary: string[];
  analyzed_at: string;
}

interface SuggestedUpdates {
  tone?: {
    formality?: number;
    opinionated?: number;
  };
  phrases?: {
    signature?: string[];
  };
  vocabulary?: {
    use_freely?: string[];
  };
}

interface ExtractionResult {
  voice_analysis: VoiceAnalysis;
  suggested_updates: SuggestedUpdates;
  markdown_report: string;
}

// ============================================
// Transcript Parsing
// ============================================

function parseSrtFormat(text: string): Turn[] | null {
  if (!text.includes(' --> ')) {
    return null;
  }
  
  const turns: Turn[] = [];
  const blocks = text.trim().split(/\n\s*\n/);
  
  for (const block of blocks) {
    const lines = block.trim().split('\n');
    if (lines.length < 2) continue;
    if (!/^\d+$/.test(lines[0].trim())) continue;
    if (!lines[1].includes(' --> ')) continue;
    
    const textContent = lines.slice(2).join(' ').trim();
    if (textContent) {
      turns.push({ speaker: 'Speaker', text: textContent });
    }
  }
  
  return turns.length > 0 ? turns : null;
}

function parseTranscript(text: string): Turn[] {
  const srtTurns = parseSrtFormat(text);
  if (srtTurns) return srtTurns;
  
  const turns: Turn[] = [];
  
  const patterns = [
    /^\[(\d{1,2}:\d{2}),\s*\d{1,2}\/\d{1,2}\/\d{2,4}\]\s*(.+?):\s*(.+)$/,
    /^(\d{1,2}:\d{2}(?::\d{2})?)\s+([A-Za-zÀ-ÿ][A-Za-zÀ-ÿ0-9\s'.\-&+]+?):\s*(.+)$/,
    /^\[(\d{1,2}:\d{2}(?::\d{2})?)\]\s*[-–]?\s*([A-Za-zÀ-ÿ][A-Za-zÀ-ÿ0-9\s'.]+?):\s*(.+)$/,
    /^\[([A-Za-zÀ-ÿ][A-Za-zÀ-ÿ0-9\s'.]+?)\]:\s*(.+)$/,
    /^([A-Z][A-Z\s'.]+?):\s*(.+)$/,
    /^([A-Za-zÀ-ÿ][A-Za-zÀ-ÿ0-9\s'.\-&+]+?):\s*(.+)$/,
  ];
  
  let currentSpeaker: string | null = null;
  let currentText: string[] = [];
  
  for (const line of text.split('\n')) {
    const trimmedLine = line.trim();
    if (!trimmedLine) continue;
    
    let matched = false;
    for (const pattern of patterns) {
      const match = trimmedLine.match(pattern);
      if (match) {
        const groups = match.slice(1);
        let speaker: string;
        let speech: string;
        
        if (groups.length === 3) {
          speaker = groups[1].trim();
          speech = groups[2].trim();
        } else {
          speaker = groups[0].trim();
          speech = groups[1].trim();
        }
        
        if (currentSpeaker && currentText.length > 0) {
          turns.push({ speaker: currentSpeaker, text: currentText.join(' ') });
        }
        
        currentSpeaker = speaker;
        currentText = [speech];
        matched = true;
        break;
      }
    }
    
    if (!matched && currentSpeaker) {
      currentText.push(trimmedLine);
    }
  }
  
  if (currentSpeaker && currentText.length > 0) {
    turns.push({ speaker: currentSpeaker, text: currentText.join(' ') });
  }
  
  return turns;
}

function identifySpeakers(turns: Turn[]): Map<string, number> {
  const counts = new Map<string, number>();
  for (const turn of turns) {
    counts.set(turn.speaker, (counts.get(turn.speaker) || 0) + 1);
  }
  return new Map([...counts.entries()].sort((a, b) => b[1] - a[1]));
}

function filterSpeakerTurns(turns: Turn[], targetSpeaker: string): string[] {
  const targetLower = targetSpeaker.toLowerCase();
  return turns
    .filter(turn => 
      turn.speaker.toLowerCase() === targetLower || 
      turn.speaker.toLowerCase().includes(targetLower)
    )
    .map(turn => turn.text);
}

// ============================================
// Analysis Functions
// ============================================

function extractPhrases(texts: string[]): { fillers: [string, number][]; starters: [string, number][] } {
  const allText = texts.join(' ').toLowerCase();
  
  const fillers: [string, number][] = [];
  const fillerPatterns = [
    /\b(you know)\b/g, /\b(i mean)\b/g, /\b(like)\b/g, /\b(right)\b/g,
    /\b(actually)\b/g, /\b(basically)\b/g, /\b(literally)\b/g,
    /\b(honestly)\b/g, /\b(obviously)\b/g, /\b(definitely)\b/g,
    /\b(kind of)\b/g, /\b(sort of)\b/g, /\b(i think)\b/g,
    /\b(i guess)\b/g, /\b(i feel like)\b/g, /\b(the thing is)\b/g,
    /\b(at the end of the day)\b/g, /\b(to be honest)\b/g,
    /\b(in terms of)\b/g, /\b(for me)\b/g, /\b(personally)\b/g,
    /\b(na prática)\b/g, /\b(tipo assim)\b/g, /\b(sabe)\b/g,
    /\b(então)\b/g, /\b(né)\b/g, /\b(basicamente)\b/g,
  ];
  
  for (const pattern of fillerPatterns) {
    const matches = allText.match(pattern);
    const count = matches ? matches.length : 0;
    if (count >= 2) {
      const match = allText.match(new RegExp(pattern.source));
      if (match) {
        fillers.push([match[1], count]);
      }
    }
  }
  
  const startersMap = new Map<string, number>();
  for (const text of texts) {
    const sentences = text.split(/[.!?]+/);
    for (const sent of sentences) {
      const words = sent.trim().split(/\s+/).slice(0, 3);
      if (words.length >= 2) {
        const starter = words.slice(0, 2).join(' ').toLowerCase();
        startersMap.set(starter, (startersMap.get(starter) || 0) + 1);
      }
    }
  }
  
  const starters: [string, number][] = [...startersMap.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 20)
    .filter(([_, count]) => count >= 2);
  
  return {
    fillers: fillers.sort((a, b) => b[1] - a[1]),
    starters
  };
}

function analyzeVocabulary(texts: string[]): { total: number; unique: number; richness: number; signature: [string, number][] } {
  const allText = texts.join(' ').toLowerCase();
  const words = allText.match(/\b[a-zà-ÿ]+\b/g) || [];
  const wordFreq = new Map<string, number>();
  
  for (const word of words) {
    wordFreq.set(word, (wordFreq.get(word) || 0) + 1);
  }
  
  const stopWords = new Set([
    'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
    'of', 'with', 'by', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
    'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
    'should', 'may', 'might', 'can', 'this', 'that', 'these', 'those',
    'it', 'its', 'i', 'me', 'my', 'we', 'our', 'you', 'your', 'he', 'she',
    'they', 'them', 'their', 'what', 'which', 'who', 'when', 'where', 'why',
    'how', 'all', 'each', 'every', 'both', 'few', 'more', 'most', 'other',
    'some', 'such', 'no', 'not', 'only', 'same', 'so', 'than', 'too', 'very',
    'just', 'also', 'now', 'here', 'there', 'then', 'if', 'because', 'as',
    'about', 'into', 'through', 'during', 'before', 'after', 'above', 'below',
    'from', 'up', 'down', 'out', 'off', 'over', 'under', 'again', 'further',
    'once', 'yeah', 'yes', 'no', 'okay', 'ok', 'um', 'uh', 'ah', 'oh', 'well',
    'like', 'get', 'got', 'going', 'go', 'know', 'think', 'say', 'said', 'see',
    'want', 'take', 'make', 'come', 'use', 'find', 'give', 'tell', 'work',
    // Portuguese stop words
    'que', 'de', 'da', 'do', 'em', 'um', 'uma', 'para', 'com', 'não', 'por',
    'mais', 'as', 'os', 'como', 'mas', 'foi', 'ao', 'ele', 'das', 'tem',
    'seu', 'sua', 'ou', 'ser', 'quando', 'muito', 'há', 'nos', 'já', 'está',
    'eu', 'também', 'só', 'pelo', 'pela', 'até', 'isso', 'ela', 'entre',
  ]);
  
  const signature: [string, number][] = [...wordFreq.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 100)
    .filter(([word, count]) => !stopWords.has(word) && word.length > 2 && count >= 3)
    .slice(0, 30);
  
  return {
    total: words.length,
    unique: wordFreq.size,
    richness: Math.round(wordFreq.size / Math.max(words.length, 1) * 1000) / 10,
    signature
  };
}

function analyzeSentenceStructure(texts: string[]): { avg: number; variety: string; questions: number; total: number } {
  const allSentences: string[] = [];
  for (const text of texts) {
    const sentences = text.split(/[.!?]+/)
      .map(s => s.trim())
      .filter(s => s.length > 0);
    allSentences.push(...sentences);
  }
  
  if (allSentences.length === 0) {
    return { avg: 0, variety: 'unknown', questions: 0, total: 0 };
  }
  
  const lengths = allSentences.map(s => s.split(/\s+/).length);
  const avgLength = lengths.reduce((a, b) => a + b, 0) / lengths.length;
  
  let variety: string;
  if (avgLength < 10) variety = 'short and punchy';
  else if (avgLength < 15) variety = 'moderate length';
  else if (avgLength < 20) variety = 'longer, detailed';
  else variety = 'complex, elaborate';
  
  const questionStarters = ['what', 'why', 'how', 'when', 'where', 'who', 'is', 'are', 'do', 'does', 'can', 'could', 'would', 'should', 'qual', 'como', 'por que', 'quando', 'onde', 'quem'];
  const questionCount = allSentences.filter(s => 
    s.includes('?') || 
    questionStarters.some(starter => s.toLowerCase().trim().startsWith(starter + ' '))
  ).length;
  
  return {
    avg: Math.round(avgLength * 10) / 10,
    variety,
    questions: Math.round(questionCount / allSentences.length * 1000) / 10,
    total: allSentences.length
  };
}

function analyzeTone(texts: string[]): Array<{ trait: string; percentage: number }> {
  const allText = texts.join(' ').toLowerCase();
  
  const markers: Record<string, string[]> = {
    enthusiasm: ['love', 'amazing', 'awesome', 'great', 'fantastic', 'incredible', 'excited', 'wow', 'adorei', 'incrível', 'fantástico'],
    hedging: ['maybe', 'perhaps', 'might', 'could be', 'i think', 'sort of', 'kind of', 'possibly', 'talvez', 'acho que', 'pode ser'],
    certainty: ['definitely', 'absolutely', 'certainly', 'clearly', 'obviously', 'without doubt', 'com certeza', 'definitivamente', 'obviamente'],
    empathy: ['understand', 'feel', 'appreciate', 'respect', 'hear you', 'get it', 'makes sense', 'entendo', 'compreendo', 'faz sentido'],
    directness: ['need to', 'have to', 'must', 'should', 'let me be clear', 'the point is', 'bottom line', 'precisa', 'tem que', 'o ponto é'],
    storytelling: ['so', 'and then', 'after that', 'suddenly', 'eventually', 'finally', 'remember when', 'então', 'daí', 'depois'],
    analytical: ['because', 'therefore', 'however', 'although', 'considering', 'in terms of', 'specifically', 'porque', 'portanto', 'considerando'],
  };
  
  const toneScores: Record<string, number> = {};
  for (const [tone, words] of Object.entries(markers)) {
    let count = 0;
    for (const word of words) {
      const regex = new RegExp(`\\b${word}\\b`, 'gi');
      const matches = allText.match(regex);
      count += matches ? matches.length : 0;
    }
    toneScores[tone] = count;
  }
  
  const total = Object.values(toneScores).reduce((a, b) => a + b, 0) || 1;
  
  return Object.entries(toneScores)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .filter(([_, count]) => count > 0)
    .map(([tone, count]) => ({
      trait: tone,
      percentage: Math.round(count / total * 1000) / 10
    }));
}

// ============================================
// Profile Generation
// ============================================

function generateAnalysis(speaker: string, texts: string[], files: string[]): ExtractionResult {
  const phrases = extractPhrases(texts);
  const vocabulary = analyzeVocabulary(texts);
  const structure = analyzeSentenceStructure(texts);
  const toneAnalysis = analyzeTone(texts);
  
  // Create voice analysis object
  const voice_analysis: VoiceAnalysis = {
    extracted_from: files,
    sample_count: texts.length,
    total_words: vocabulary.total,
    sentence_structure: {
      avg_length: structure.avg,
      variety: structure.variety,
      question_ratio: structure.questions
    },
    communication_style: toneAnalysis,
    characteristic_expressions: phrases.fillers.slice(0, 10).map(([p]) => p),
    sentence_starters: phrases.starters.slice(0, 10).map(([s]) => {
      return s.split(' ').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
    }),
    signature_vocabulary: vocabulary.signature.slice(0, 15).map(([w]) => w),
    analyzed_at: new Date().toISOString()
  };
  
  // Generate suggested updates for author profile
  const suggested_updates: SuggestedUpdates = {};
  
  // Suggest formality based on structure and vocabulary
  let formality = 5;
  if (structure.variety === 'short and punchy') formality = 3;
  else if (structure.variety === 'complex, elaborate') formality = 7;
  
  // Suggest opinionated based on tone
  let opinionated = 5;
  const certaintyScore = toneAnalysis.find(t => t.trait === 'certainty')?.percentage || 0;
  const hedgingScore = toneAnalysis.find(t => t.trait === 'hedging')?.percentage || 0;
  const directnessScore = toneAnalysis.find(t => t.trait === 'directness')?.percentage || 0;
  
  if (certaintyScore > 20 || directnessScore > 20) opinionated = 7;
  else if (hedgingScore > 25) opinionated = 3;
  
  suggested_updates.tone = { formality, opinionated };
  
  if (phrases.fillers.length > 0) {
    suggested_updates.phrases = {
      signature: phrases.fillers.slice(0, 5).map(([p]) => p)
    };
  }
  
  if (vocabulary.signature.length > 0) {
    suggested_updates.vocabulary = {
      use_freely: vocabulary.signature.slice(0, 10).map(([w]) => w)
    };
  }
  
  // Generate markdown report
  const markdown = generateMarkdownReport(speaker, voice_analysis, suggested_updates, vocabulary.richness);
  
  return {
    voice_analysis,
    suggested_updates,
    markdown_report: markdown
  };
}

function generateMarkdownReport(
  speaker: string, 
  analysis: VoiceAnalysis, 
  suggestions: SuggestedUpdates,
  vocabRichness: number
): string {
  const lines: string[] = [];
  
  lines.push(`# Voice Analysis: ${speaker}`);
  lines.push('');
  lines.push(`*Analyzed ${analysis.sample_count} speaking turns, ${analysis.total_words.toLocaleString()} words*`);
  lines.push('');
  
  // Data quality warning
  if (analysis.sample_count < 50) {
    lines.push(`> ⚠️ **Limited data**: Only ${analysis.sample_count} speaking turns found.`);
    lines.push(`> Results may not fully represent speaking patterns. Consider adding more transcripts.`);
    lines.push('');
  }
  
  // Speaking Style
  lines.push('## Speaking Style');
  lines.push('');
  lines.push(`- **Sentence length**: ${analysis.sentence_structure.variety} (~${analysis.sentence_structure.avg_length} words avg)`);
  lines.push(`- **Questions**: ${analysis.sentence_structure.question_ratio}% of sentences`);
  lines.push(`- **Vocabulary richness**: ${vocabRichness}% unique words`);
  lines.push('');
  
  // Communication Style
  if (analysis.communication_style.length > 0) {
    lines.push('## Communication Style');
    lines.push('');
    for (const { trait, percentage } of analysis.communication_style) {
      const label = trait.charAt(0).toUpperCase() + trait.slice(1);
      lines.push(`- **${label}**: ${percentage}%`);
    }
    lines.push('');
  }
  
  // Characteristic Expressions
  if (analysis.characteristic_expressions.length > 0) {
    lines.push('## Characteristic Expressions');
    lines.push('');
    for (const expr of analysis.characteristic_expressions) {
      lines.push(`- "${expr}"`);
    }
    lines.push('');
  }
  
  // Sentence Starters
  if (analysis.sentence_starters.length > 0) {
    lines.push('## Common Sentence Starters');
    lines.push('');
    for (const starter of analysis.sentence_starters.slice(0, 8)) {
      lines.push(`- "${starter}..."`);
    }
    lines.push('');
  }
  
  // Signature Vocabulary
  if (analysis.signature_vocabulary.length > 0) {
    lines.push('## Signature Vocabulary');
    lines.push('');
    lines.push(analysis.signature_vocabulary.map(w => `**${w}**`).join(', '));
    lines.push('');
  }
  
  // Suggestions
  lines.push('---');
  lines.push('');
  lines.push('## Suggested Author Profile Updates');
  lines.push('');
  lines.push('Based on this analysis, consider these settings:');
  lines.push('');
  lines.push('```json');
  lines.push(JSON.stringify(suggestions, null, 2));
  lines.push('```');
  lines.push('');
  
  // Writing Instructions
  lines.push('## Writing Instructions');
  lines.push('');
  lines.push(`1. **Sentence structure**: Use ${analysis.sentence_structure.variety} sentences (~${analysis.sentence_structure.avg_length} words)`);
  
  if (analysis.sentence_structure.question_ratio > 15) {
    lines.push('2. **Engagement**: Include rhetorical questions frequently');
  } else {
    lines.push('2. **Engagement**: Use statements more than questions');
  }
  
  if (analysis.communication_style.length > 0) {
    lines.push(`3. **Tone**: Lean toward ${analysis.communication_style[0].trait} language`);
  }
  
  if (analysis.characteristic_expressions.length > 0) {
    const exprs = analysis.characteristic_expressions.slice(0, 3).map(e => `"${e}"`).join(', ');
    lines.push(`4. **Natural speech**: Occasionally include expressions like ${exprs}`);
  }
  
  if (analysis.signature_vocabulary.length > 0) {
    const words = analysis.signature_vocabulary.slice(0, 5).join(', ');
    lines.push(`5. **Vocabulary**: Favor words like: ${words}`);
  }
  
  lines.push('');
  
  return lines.join('\n');
}

// ============================================
// Main Execution
// ============================================

const { values, positionals } = parseArgs({
  args: Bun.argv.slice(2),
  options: {
    speaker: { type: 'string', short: 's' },
    'list-speakers': { type: 'boolean', short: 'l' },
    output: { type: 'string', short: 'o' },
    json: { type: 'boolean' },
    'author-json': { type: 'boolean' },
    help: { type: 'boolean', short: 'h' }
  },
  allowPositionals: true
});

if (values.help || positionals.length === 0) {
  console.log(`
Voice Extractor for Article Writer
===================================

Extract voice characteristics from transcripts to enhance author profiles.

Usage: bun run voice-extractor.ts [options] <transcript files...>

Options:
  -s, --speaker <name>    Target speaker name to extract
  -l, --list-speakers     List all speakers found in transcripts
  -o, --output <file>     Output file (default: stdout)
      --json              Output full JSON (voice_analysis + suggested_updates)
      --author-json       Output only voice_analysis for direct merge to authors.json
  -h, --help              Show this help message

Examples:
  # List all speakers
  bun run voice-extractor.ts --list-speakers transcript.txt

  # Extract and show markdown report
  bun run voice-extractor.ts --speaker "John" transcript.txt

  # Output JSON for merging into authors.json
  bun run voice-extractor.ts --speaker "John" --author-json transcript.txt

  # Process multiple transcripts
  bun run voice-extractor.ts --speaker "John" -o profile.json --json t1.txt t2.txt t3.txt
`);
  process.exit(0);
}

// Load and parse all transcripts
const allTurns: Turn[] = [];
const fileNames: string[] = [];

for (const transcriptPath of positionals) {
  if (!existsSync(transcriptPath)) {
    console.warn(`Warning: ${transcriptPath} not found, skipping`);
    continue;
  }
  
  const text = readFileSync(transcriptPath, 'utf-8');
  const turns = parseTranscript(text);
  allTurns.push(...turns);
  fileNames.push(transcriptPath);
}

if (allTurns.length === 0) {
  console.error('Error: No valid transcript data found');
  process.exit(1);
}

// List speakers mode
if (values['list-speakers']) {
  const speakers = identifySpeakers(allTurns);
  console.log('Speakers found:');
  for (const [speaker, count] of speakers) {
    console.log(`  - ${speaker}: ${count} turns`);
  }
  process.exit(0);
}

// Need a speaker to extract
if (!values.speaker) {
  const speakers = identifySpeakers(allTurns);
  console.log('Available speakers (use --speaker to select one):');
  for (const [speaker, count] of speakers) {
    console.log(`  - ${speaker}: ${count} turns`);
  }
  process.exit(1);
}

// Extract speaker's turns
const texts = filterSpeakerTurns(allTurns, values.speaker);
if (texts.length === 0) {
  console.error(`Error: No turns found for speaker '${values.speaker}'`);
  const speakers = identifySpeakers(allTurns);
  console.log('Available speakers:');
  for (const [speaker] of speakers) {
    console.log(`  - ${speaker}`);
  }
  process.exit(1);
}

// Generate analysis
const result = generateAnalysis(values.speaker, texts, fileNames);

// Output
let output: string;
if (values['author-json']) {
  // Only voice_analysis for direct merge
  output = JSON.stringify({ voice_analysis: result.voice_analysis }, null, 2);
} else if (values.json) {
  // Full result
  output = JSON.stringify({
    voice_analysis: result.voice_analysis,
    suggested_updates: result.suggested_updates
  }, null, 2);
} else {
  // Markdown report
  output = result.markdown_report;
}

if (values.output) {
  writeFileSync(values.output, output, 'utf-8');
  console.log(`Voice analysis written to ${values.output}`);
} else {
  console.log(output);
}
