use anyhow::Result;
use spin_sdk::{
    http::{IntoResponse, Method, Request, Response},
    http_component,
};
use tract_onnx::prelude::*;
mod auth;
use auth::check_access;
use std::fs;

#[http_component]
async fn handle_imageclassify(req: Request) -> Result<impl IntoResponse> {
    if req.method().to_owned() == Method::Get {
        return Ok(Response::builder()
            .status(200)
            .header("content-type", "text/html")
            .body(fs::read_to_string("imageclassify.html").unwrap())
            .build()
        )
    }

    if !check_access(req.header("authorization").unwrap().as_str().unwrap()).await {
        return Ok(Response::builder()
            .status(403)
            .header("content-type", "text/plain")
            .body(format!("Access denied"))
            .build());
    }

    let model = tract_onnx::onnx()
        .model_for_path("mobilenetv2-7.onnx")?
        .into_optimized()?
        .into_runnable()?;

    let image_bytes = req.body();

    let image = image::load_from_memory(image_bytes).unwrap().to_rgb8();

    let resized =
        image::imageops::resize(&image, 224, 224, ::image::imageops::FilterType::Triangle);
    let image: Tensor = tract_ndarray::Array4::from_shape_fn((1, 3, 224, 224), |(_, c, y, x)| {
        let mean = [0.485, 0.456, 0.406][c];
        let std = [0.229, 0.224, 0.225][c];
        (resized[(x as _, y as _)][c] as f32 / 255.0 - mean) / std
    })
    .into();

    let result = model.run(tvec!(image.into()))?;

    let best = result[0]
        .to_array_view::<f32>()?
        .iter()
        .cloned()
        .zip(2..)
        .max_by(|a, b| a.0.partial_cmp(&b.0).unwrap());

    let labels = fs::read_to_string("image_slim_labels.txt").unwrap();
    let lines: Vec<&str> = labels.lines().collect();
    let line_number = best.unwrap().1 - 1;
    let result = lines[line_number];

    Ok(Response::builder()
        .status(200)
        .header("content-type", "text/plain")
        .body(result)
        .build())
}
