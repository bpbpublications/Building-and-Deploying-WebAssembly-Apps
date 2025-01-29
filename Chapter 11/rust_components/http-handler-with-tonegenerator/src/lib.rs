mod tonegeneratorimports;
mod multiplierimports;

use multiplierimports::example::multiply::multiplier::mul;
use tonegeneratorimports::example::tonegenerator::tonegeneratorsynth::{nextsample,setnote};

use wasi::http::types::{
    Fields, IncomingRequest, OutgoingBody, OutgoingResponse, ResponseOutparam,
};

wasi::http::incoming_handler::export!(Example);

struct Example;

impl exports::wasi::http::incoming_handler::Guest for Example {
    fn handle(_request: IncomingRequest, response_out: ResponseOutparam) {
        if _request.path_with_query().unwrap() == "/music" {
            let headers = Fields::new();
            headers.set(&"content-type".to_string(), &["audio/wav".as_bytes().to_vec()]).unwrap();
            let resp = OutgoingResponse::new(headers);
            let body = resp.body().unwrap();

            ResponseOutparam::set(response_out, Ok(resp));

            let out = body.write().unwrap();

            const SAMPLERATE: usize = 44100;
            const SECONDS: usize = 5;
            const TRACK_LENGTH: usize = SAMPLERATE * SECONDS;
            let notenumbers: [f32; SECONDS] = [60.0, 62.0, 64.0, 65.0, 67.0];

            // Preparing WAV header
            let header = create_wav_header(SAMPLERATE as u32, 1, 32, TRACK_LENGTH as u32);
            out.blocking_write_and_flush(&header).unwrap(); // Write the WAV header to the output

            for n in 0..TRACK_LENGTH {
                if n % SAMPLERATE == 0 {
                    setnote(notenumbers[n / SAMPLERATE])
                }
                let sample = nextsample();
                // Convert f32 sample to bytes in little-endian format
                let sample_bytes = sample.to_le_bytes();
                out.blocking_write_and_flush(&sample_bytes).unwrap();
            }

            drop(out);

            OutgoingBody::finish(body, None).unwrap();
        } else { 
            let resp = OutgoingResponse::new(Fields::new());
            let body = resp.body().unwrap();

            ResponseOutparam::set(response_out, Ok(resp));

            let out = body.write().unwrap();
       
            let product = mul(4, 8);
            let outstring = format!("Hello {}", product);
            out.blocking_write_and_flush(outstring.as_bytes()).unwrap();
            drop(out);

            OutgoingBody::finish(body, None).unwrap();
        }
    }
}


fn create_wav_header(sample_rate: u32, num_channels: u16, bits_per_sample: u16, num_samples: u32) -> Vec<u8> {
    let block_align = num_channels * bits_per_sample / 8;
    let byte_rate = sample_rate * u32::from(block_align);
    let data_chunk_size = num_samples * u32::from(block_align);
    let file_size = 36 + data_chunk_size; // 36 bytes for header + data chunk size

    let mut header = Vec::new();

    // RIFF chunk descriptor
    header.extend_from_slice(b"RIFF");
    header.extend_from_slice(&(file_size + 8).to_le_bytes()); // File size + 8 for RIFF and size fields
    header.extend_from_slice(b"WAVE");

    // fmt subchunk
    header.extend_from_slice(b"fmt ");
    header.extend_from_slice(&16u32.to_le_bytes()); // PCM chunk size
    header.extend_from_slice(&3u16.to_le_bytes());
    header.extend_from_slice(&num_channels.to_le_bytes());
    header.extend_from_slice(&sample_rate.to_le_bytes());
    header.extend_from_slice(&byte_rate.to_le_bytes());
    header.extend_from_slice(&block_align.to_le_bytes());
    header.extend_from_slice(&bits_per_sample.to_le_bytes());

    // data subchunk
    header.extend_from_slice(b"data");
    header.extend_from_slice(&data_chunk_size.to_le_bytes());

    header
}
