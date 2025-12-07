# Transcript Format Examples

The extraction script supports multiple transcript formats. Here are examples of each:

## Format 1: Simple Speaker Labels

```
John: This is what I said about the project.
Jane: And this is my response to that.
John: Let me follow up on that point.
```

## Format 2: Bracketed Speakers

```
[John]: This is what I said about the project.
[Jane]: And this is my response to that.
[John]: Let me follow up on that point.
```

## Format 3: Timestamped Transcripts (Bracketed)

```
[00:01:23] John: This is what I said about the project.
[00:01:45] Jane: And this is my response to that.
[00:02:10] John: Let me follow up on that point.
```

## Format 4: Timestamped Transcripts (Inline)

```
59:54 Marcelo Guerra: Teve uma semana que eu quase fui bloqueado.
59:58 José Alves de Souza Neto: Mas você tava montando uso ou nem se preocupa?
01:00:14 Marcelo Guerra: Eu quase fui bloqueado, cheguei no limite.
```

## Format 5: WhatsApp Export Format

```
[17:30, 12/6/2025] Fernando dos Santos: To meio que brincando e ajustando uns detalhes no código
[17:49, 12/6/2025] Marcelo Guerra: Ela também!
[17:49, 12/6/2025] Marcelo Guerra: Voltando agora
[17:52, 12/6/2025] +55 14 99166-6802: Tinha um código pra mexer mas é aniversário da sobrinha
```

## Format 6: SRT Subtitle Format

Standard subtitle format from video editors, YouTube, etc. Note: SRT files don't have speaker labels, so all text is attributed to "Speaker".

```
1
00:00:00,560 --> 00:00:07,260
In this recording, I'm going to try and speak over the 30-second window.

2
00:00:07,260 --> 00:00:14,800
So I'm going to start with some random speech and have some pauses in between, like now.

3
00:00:14,800 --> 00:00:20,720
This will generate, as we know, another segment within the 30-second window that we're going
to start with.
```

## Format 7: Uppercase Speaker Names

```
JOHN: This is what I said about the project.
JANE: And this is my response to that.
JOHN: Let me follow up on that point.
```

## Speaker Name Variations

The script handles various speaker name formats:
- Simple names: `John`, `Jane`
- Full names: `José Alves de Souza Neto`, `Marcelo Guerra`
- Names with special characters: `B&C - Fernando dos Santos`
- Phone numbers (WhatsApp): `+55 14 99166-6802`
- Accented characters: `João`, `José`, `André`

## Multi-line Turns

The script handles multi-line speaking turns where text continues without a new speaker label:

```
John: This is a longer thought that I'm expressing
and it continues on the next line without
a new speaker label appearing.
Jane: Got it, that makes sense.
```

## Mixed Formats

The script can handle transcripts that mix formats, but for best results use consistent formatting throughout.

## Common Sources

These formats are commonly exported from:
- YouTube auto-captions (SRT format)
- Otter.ai transcripts
- Descript exports
- Rev.com transcriptions
- WhatsApp chat exports
- Zoom transcripts
- Video editing software (SRT)
- Manual transcriptions
