// sanity_effect.gdshader
// Post-process shader untuk efek visual kegilaan (sanity) Whispering Rooms.
//
// Parameter (di-set dari SanitySystem.gd via ShaderMaterial):
//   vignette_intensity: float (0.0 = tidak ada, 1.0 = sangat tebal)
//   chroma_intensity:   float (0.0 = tidak ada, 0.12 = aberrasi parah)
//   pulse_speed:        float (0.0 = tidak berdenyut, 3.0 = berdenyut cepat)
//
// Cara pakai:
//   1. Buat ColorRect yang mengisi seluruh layar (full rect anchor)
//   2. Assign shader ini sebagai ShaderMaterial
//   3. Atur blend mode ColorRect ke "Mix" dengan alpha transparency

shader_type canvas_item;

// ─── PARAMETER YANG DI-SET DARI SCRIPT ───────────────────────────────────────

/// Tebal vignette: 0.0 = tidak ada, 1.0 = hampir seluruh layar hitam.
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.0;

/// Kekuatan chromatic aberration: 0.0 = tidak ada, 0.12 = sangat kuat.
uniform float chroma_intensity : hint_range(0.0, 0.15) = 0.0;

/// Kecepatan denyut vignette (untuk efek panik): 0.0 = diam.
uniform float pulse_speed : hint_range(0.0, 5.0) = 0.0;

/// Warna vignette (default: hitam pekat).
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// Untuk membaca layar di belakang HUD di Godot 4
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// ─── FRAGMENT SHADER ──────────────────────────────────────────────────────────

void fragment() {
    vec2 uv = UV;
    vec2 screen_uv = SCREEN_UV;

    // ─── CHROMATIC ABERRATION ───────────────────────────────────────────────
    // Geser channel R dan B berlawanan arah untuk efek "retina terlepas"
    vec4 color;
    if (chroma_intensity > 0.001) {
        vec2 offset = (screen_uv - 0.5) * chroma_intensity;
        float r = texture(screen_texture, screen_uv + offset).r;
        float g = texture(screen_texture, screen_uv).g;
        float b = texture(screen_texture, screen_uv - offset).b;
        color = vec4(r, g, b, 1.0);
    } else {
        color = texture(screen_texture, screen_uv);
    }

    // ─── VIGNETTE ──────────────────────────────────────────────────────────
    // Kalkulasi kekuatan vignette berdasarkan jarak dari pusat layar
    vec2 center_offset = screen_uv - 0.5;
    float dist_from_center = length(center_offset);

    // Pulse effect: vignette berdenyut saat sanity kritis
    float pulse_factor = 1.0;
    if (pulse_speed > 0.001) {
        pulse_factor = 1.0 + sin(TIME * pulse_speed) * 0.15;
    }

    // Kurva vignette — smooth di tepi, pekat di pojok
    float vignette_curve = smoothstep(
        0.2,                           // inner radius (mulai gelap dari sini)
        0.85 - (vignette_intensity * 0.3),  // outer radius (makin sempit saat intensitas tinggi)
        dist_from_center * 1.5
    );

    float effective_vignette = vignette_curve * vignette_intensity * pulse_factor;
    effective_vignette = clamp(effective_vignette, 0.0, 0.98);

    // Campurkan warna asli dengan warna vignette
    color.rgb = mix(color.rgb, vignette_color.rgb, effective_vignette);

    // ─── NOISE GRAIN (sanity noise saat sangat rendah) ──────────────────────
    // Grain halus muncul saat vignette sangat tebal
    if (vignette_intensity > 0.7) {
        float grain_amount = (vignette_intensity - 0.7) / 0.3;  // 0.0 – 1.0
        // Pseudo-random noise berdasarkan UV dan TIME
        float noise_t = TIME * 30.0;
        float noise = fract(sin(dot(screen_uv * 100.0 + noise_t, vec2(127.1, 311.7))) * 43758.5453);
        noise = (noise - 0.5) * 0.08 * grain_amount;
        color.rgb += vec3(noise);
    }

    COLOR = color;
}
