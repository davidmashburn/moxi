#include <AudioToolbox/AudioToolbox.h>

#include <math.h>
#include <stdint.h>
#include <stdatomic.h>
#include <stdio.h>
#include <string.h>

enum {
    SIGNAL_AUDIO_TABLE_SIZE = 128,
    SIGNAL_AUDIO_TABLE_COUNT = 2,
    SIGNAL_AUDIO_EXPORT_SAMPLE_RATE = 44100,
    SIGNAL_AUDIO_EXPORT_SECONDS = 2,
    SIGNAL_AUDIO_EXPORT_CHUNK_FRAMES = 512
};

static const float kSignalAudioFrequencyHz = 220.0f;
static const float kSignalAudioGain = 0.15f;
static const float kSignalAudioFadeSeconds = 0.010f;

_Static_assert(
    sizeof(float) == sizeof(uint32_t),
    "signal audio requires 32-bit float samples"
);

/*
 * The table samples are atomic so a callback can finish reading an old table
 * while the control thread reuses that table as the next pending table. The
 * active-table index and generation make committed table snapshots coherent
 * at callback boundaries; the atomics also make the short handoff window safe.
 */
static _Atomic uint32_t g_signal_audio_tables[
    SIGNAL_AUDIO_TABLE_COUNT
][SIGNAL_AUDIO_TABLE_SIZE];
static _Atomic uint32_t g_signal_audio_active_table = 0U;
static _Atomic uint32_t g_signal_audio_table_generation = 0U;
static _Atomic int g_signal_audio_enabled = 0;

/* These values are owned by the control thread and are never used by the
 * realtime callback. The public table API is intended for that same thread. */
static unsigned int g_signal_audio_pending_table = 1U;
static AudioUnit g_signal_audio_unit = NULL;
static int g_signal_audio_initialized = 0;
static int g_signal_audio_running = 0;
static float g_signal_audio_phase_increment =
    kSignalAudioFrequencyHz / (float)SIGNAL_AUDIO_EXPORT_SAMPLE_RATE;
static float g_signal_audio_gain_step = kSignalAudioGain / 441.0f;

/* Callback-owned state. It is reset only after the output unit has stopped. */
static float g_signal_audio_render_phase = 0.0f;
static float g_signal_audio_render_gain = 0.0f;
static float g_signal_audio_render_table[SIGNAL_AUDIO_TABLE_SIZE];

static uint32_t signal_audio_float_to_bits(float value) {
    uint32_t bits;
    memcpy(&bits, &value, sizeof(bits));
    return bits;
}

static float signal_audio_bits_to_float(uint32_t bits) {
    float value;
    memcpy(&value, &bits, sizeof(value));
    return value;
}

static float signal_audio_clamp_sample(float value) {
    if (!isfinite(value)) {
        return 0.0f;
    }
    if (value > 1.0f) {
        return 1.0f;
    }
    if (value < -1.0f) {
        return -1.0f;
    }
    return value;
}

static int signal_audio_copy_active_table(float destination[128]) {
    /* Never spin behind a preempted control thread in the audio callback. */
    float candidate[SIGNAL_AUDIO_TABLE_SIZE];
    for (unsigned int attempt = 0; attempt < 3; attempt++) {
        uint32_t generation = atomic_load_explicit(
            &g_signal_audio_table_generation,
            memory_order_acquire
        );
        if ((generation & 1U) != 0U) {
            continue;
        }

        unsigned int active_table = atomic_load_explicit(
            &g_signal_audio_active_table,
            memory_order_acquire
        );
        active_table %= SIGNAL_AUDIO_TABLE_COUNT;
        for (unsigned int index = 0U; index < SIGNAL_AUDIO_TABLE_SIZE; index++) {
            uint32_t bits = atomic_load_explicit(
                &g_signal_audio_tables[active_table][index],
                memory_order_relaxed
            );
            candidate[index] = signal_audio_bits_to_float(bits);
        }

        uint32_t end_generation = atomic_load_explicit(
            &g_signal_audio_table_generation,
            memory_order_acquire
        );
        if (
            generation == end_generation
            && (end_generation & 1U) == 0U
        ) {
            memcpy(destination, candidate, sizeof(candidate));
            return 1;
        }
    }
    return 0;
}

static float signal_audio_wavetable_sample(
    const float table[128],
    float phase
) {
    float position = phase * (float)SIGNAL_AUDIO_TABLE_SIZE;
    if (position >= (float)SIGNAL_AUDIO_TABLE_SIZE) {
        position -= (float)SIGNAL_AUDIO_TABLE_SIZE;
    }

    unsigned int index = (unsigned int)position;
    if (index >= SIGNAL_AUDIO_TABLE_SIZE) {
        index = 0U;
        position = 0.0f;
    }

    unsigned int next_index = index + 1U;
    if (next_index == SIGNAL_AUDIO_TABLE_SIZE) {
        next_index = 0U;
    }

    float fraction = position - (float)index;
    return table[index] + (table[next_index] - table[index]) * fraction;
}

static float signal_audio_advance_phase(float phase, float increment) {
    phase += increment;
    while (phase >= 1.0f) {
        phase -= 1.0f;
    }
    while (phase < 0.0f) {
        phase += 1.0f;
    }
    return phase;
}

static float signal_audio_step_gain(float gain, float target) {
    float step = g_signal_audio_gain_step;
    if (gain < target) {
        gain += step;
        if (gain > target) {
            gain = target;
        }
    } else if (gain > target) {
        gain -= step;
        if (gain < target) {
            gain = target;
        }
    }
    return gain;
}

static OSStatus signal_audio_render(
    void *input_ref_con,
    AudioUnitRenderActionFlags *action_flags,
    const AudioTimeStamp *timestamp,
    UInt32 bus_number,
    UInt32 number_of_frames,
    AudioBufferList *io_data
) {
    (void)input_ref_con;
    (void)action_flags;
    (void)timestamp;
    (void)bus_number;

    if (io_data == NULL || number_of_frames == 0U) {
        return noErr;
    }

    /* Keep the last complete table if an edit is being published. */
    (void)signal_audio_copy_active_table(g_signal_audio_render_table);

    float phase = g_signal_audio_render_phase;
    float gain = g_signal_audio_render_gain;
    int enabled = atomic_load_explicit(
        &g_signal_audio_enabled,
        memory_order_relaxed
    );
    float target_gain = enabled != 0 ? kSignalAudioGain : 0.0f;

    for (UInt32 frame = 0U; frame < number_of_frames; frame++) {
        gain = signal_audio_step_gain(gain, target_gain);
        float sample = signal_audio_wavetable_sample(g_signal_audio_render_table, phase) * gain;

        for (
            UInt32 buffer_index = 0U;
            buffer_index < io_data->mNumberBuffers;
            buffer_index++
        ) {
            AudioBuffer *buffer = &io_data->mBuffers[buffer_index];
            if (buffer->mData == NULL) {
                continue;
            }

            UInt32 channel_count = buffer->mNumberChannels;
            if (channel_count == 0U) {
                channel_count = 1U;
            }

            float *samples = (float *)buffer->mData;
            for (UInt32 channel = 0U; channel < channel_count; channel++) {
                samples[(size_t)frame * channel_count + channel] = sample;
            }
        }

        phase = signal_audio_advance_phase(
            phase,
            g_signal_audio_phase_increment
        );
    }

    g_signal_audio_render_phase = phase;
    g_signal_audio_render_gain = gain;
    return noErr;
}

static void signal_audio_dispose_unit(AudioUnit unit, int initialized) {
    if (initialized != 0) {
        (void)AudioUnitUninitialize(unit);
    }
    (void)AudioComponentInstanceDispose(unit);
}

static double signal_audio_valid_sample_rate(double sample_rate) {
    if (!isfinite(sample_rate) || sample_rate < 8000.0) {
        return (double)SIGNAL_AUDIO_EXPORT_SAMPLE_RATE;
    }
    return sample_rate;
}

static void signal_audio_set_runtime_parameters(double sample_rate) {
    sample_rate = signal_audio_valid_sample_rate(sample_rate);
    g_signal_audio_phase_increment =
        (float)(kSignalAudioFrequencyHz / sample_rate);

    float fade_samples = (float)(kSignalAudioFadeSeconds * sample_rate);
    if (fade_samples < 1.0f) {
        fade_samples = 1.0f;
    }
    g_signal_audio_gain_step = kSignalAudioGain / fade_samples;
}

int signal_audio_start(void) {
    if (g_signal_audio_unit != NULL) {
        return 1;
    }

    if (
        !atomic_is_lock_free(&g_signal_audio_active_table)
        || !atomic_is_lock_free(&g_signal_audio_tables[0][0])
        || !atomic_is_lock_free(&g_signal_audio_enabled)
        || !atomic_is_lock_free(&g_signal_audio_table_generation)
    ) {
        return 0;
    }

    AudioComponentDescription description = {
        .componentType = kAudioUnitType_Output,
        .componentSubType = kAudioUnitSubType_DefaultOutput,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags = 0U,
        .componentFlagsMask = 0U
    };
    AudioComponent component = AudioComponentFindNext(NULL, &description);
    if (component == NULL) {
        return 0;
    }

    AudioUnit unit = NULL;
    if (AudioComponentInstanceNew(component, &unit) != noErr || unit == NULL) {
        return 0;
    }

    AURenderCallbackStruct callback = {
        .inputProc = signal_audio_render,
        .inputProcRefCon = NULL
    };
    if (
        AudioUnitSetProperty(
            unit,
            kAudioUnitProperty_SetRenderCallback,
            kAudioUnitScope_Input,
            0U,
            &callback,
            (UInt32)sizeof(callback)
        ) != noErr
    ) {
        signal_audio_dispose_unit(unit, 0);
        return 0;
    }

    double sample_rate = (double)SIGNAL_AUDIO_EXPORT_SAMPLE_RATE;
    AudioStreamBasicDescription device_format;
    memset(&device_format, 0, sizeof(device_format));
    UInt32 device_format_size = (UInt32)sizeof(device_format);
    if (
        AudioUnitGetProperty(
            unit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Output,
            0U,
            &device_format,
            &device_format_size
        ) == noErr
    ) {
        sample_rate = signal_audio_valid_sample_rate(device_format.mSampleRate);
    }

    AudioStreamBasicDescription format;
    memset(&format, 0, sizeof(format));
    format.mSampleRate = sample_rate;
    format.mFormatID = kAudioFormatLinearPCM;
    format.mFormatFlags = kAudioFormatFlagsNativeFloatPacked;
    format.mBytesPerPacket = (UInt32)sizeof(float);
    format.mFramesPerPacket = 1U;
    format.mBytesPerFrame = (UInt32)sizeof(float);
    format.mChannelsPerFrame = 1U;
    format.mBitsPerChannel = (UInt32)(sizeof(float) * 8U);

    if (
        AudioUnitSetProperty(
            unit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Input,
            0U,
            &format,
            (UInt32)sizeof(format)
        ) != noErr
    ) {
        signal_audio_dispose_unit(unit, 0);
        return 0;
    }

    if (AudioUnitInitialize(unit) != noErr) {
        signal_audio_dispose_unit(unit, 0);
        return 0;
    }

    signal_audio_set_runtime_parameters(format.mSampleRate);
    g_signal_audio_unit = unit;
    g_signal_audio_initialized = 1;
    g_signal_audio_running = 0;
    g_signal_audio_render_phase = 0.0f;
    g_signal_audio_render_gain = 0.0f;

    /* An enable request made before start is honored, but initialization
     * itself never starts the output unit. */
    if (
        atomic_load_explicit(&g_signal_audio_enabled, memory_order_relaxed)
        != 0
    ) {
        if (AudioOutputUnitStart(unit) != noErr) {
            atomic_store_explicit(
                &g_signal_audio_enabled,
                0,
                memory_order_relaxed
            );
            g_signal_audio_unit = NULL;
            g_signal_audio_initialized = 0;
            signal_audio_dispose_unit(unit, 1);
            return 0;
        }
        g_signal_audio_running = 1;
    }

    return 1;
}

void signal_audio_set_sample(int index, float value) {
    if (index < 0 || index >= SIGNAL_AUDIO_TABLE_SIZE) {
        return;
    }

    value = signal_audio_clamp_sample(value);
    unsigned int pending_table = g_signal_audio_pending_table;
    atomic_store_explicit(
        &g_signal_audio_tables[pending_table][(unsigned int)index],
        signal_audio_float_to_bits(value),
        memory_order_relaxed
    );
}

void signal_audio_commit(void) {
    unsigned int pending_table = g_signal_audio_pending_table;

    atomic_fetch_add_explicit(
        &g_signal_audio_table_generation,
        1U,
        memory_order_acq_rel
    );
    unsigned int old_active_table = atomic_exchange_explicit(
        &g_signal_audio_active_table,
        pending_table,
        memory_order_acq_rel
    );
    g_signal_audio_pending_table = old_active_table % SIGNAL_AUDIO_TABLE_COUNT;
    atomic_fetch_add_explicit(
        &g_signal_audio_table_generation,
        1U,
        memory_order_release
    );
}

int signal_audio_enable(int enabled) {
    int requested = enabled != 0 ? 1 : 0;
    atomic_store_explicit(
        &g_signal_audio_enabled,
        requested,
        memory_order_relaxed
    );

    if (
        requested == 0
        || g_signal_audio_initialized == 0
        || g_signal_audio_unit == NULL
        || g_signal_audio_running != 0
    ) {
        return requested == 0 || g_signal_audio_running != 0;
    }

    if (AudioOutputUnitStart(g_signal_audio_unit) == noErr) {
        g_signal_audio_running = 1;
    } else {
        atomic_store_explicit(
            &g_signal_audio_enabled,
            0,
            memory_order_relaxed
        );
    }
    return g_signal_audio_running;
}

void signal_audio_stop(void) {
    atomic_store_explicit(
        &g_signal_audio_enabled,
        0,
        memory_order_relaxed
    );

    if (g_signal_audio_unit == NULL) {
        return;
    }

    if (g_signal_audio_running != 0) {
        (void)AudioOutputUnitStop(g_signal_audio_unit);
    }
    signal_audio_dispose_unit(g_signal_audio_unit, g_signal_audio_initialized);
    g_signal_audio_unit = NULL;
    g_signal_audio_initialized = 0;
    g_signal_audio_running = 0;
    g_signal_audio_render_phase = 0.0f;
    g_signal_audio_render_gain = 0.0f;
}

static int signal_audio_write_bytes(
    FILE *file,
    const void *bytes,
    size_t byte_count
) {
    return fwrite(bytes, 1U, byte_count, file) == byte_count;
}

static int signal_audio_write_u16_le(FILE *file, uint16_t value) {
    unsigned char bytes[2];
    bytes[0] = (unsigned char)(value & 0xffU);
    bytes[1] = (unsigned char)(value >> 8U);
    return signal_audio_write_bytes(file, bytes, sizeof(bytes));
}

static int signal_audio_write_u32_le(FILE *file, uint32_t value) {
    unsigned char bytes[4];
    bytes[0] = (unsigned char)(value & 0xffU);
    bytes[1] = (unsigned char)((value >> 8U) & 0xffU);
    bytes[2] = (unsigned char)((value >> 16U) & 0xffU);
    bytes[3] = (unsigned char)(value >> 24U);
    return signal_audio_write_bytes(file, bytes, sizeof(bytes));
}

static int signal_audio_write_wav_header(FILE *file, uint32_t frame_count) {
    uint32_t data_bytes = frame_count * (uint32_t)sizeof(int16_t);
    uint32_t riff_size = 36U + data_bytes;
    const unsigned char riff[] = {'R', 'I', 'F', 'F'};
    const unsigned char wave[] = {'W', 'A', 'V', 'E'};
    const unsigned char fmt[] = {'f', 'm', 't', ' '};
    const unsigned char data[] = {'d', 'a', 't', 'a'};

    return
        signal_audio_write_bytes(file, riff, sizeof(riff))
        && signal_audio_write_u32_le(file, riff_size)
        && signal_audio_write_bytes(file, wave, sizeof(wave))
        && signal_audio_write_bytes(file, fmt, sizeof(fmt))
        && signal_audio_write_u32_le(file, 16U)
        && signal_audio_write_u16_le(file, 1U)
        && signal_audio_write_u16_le(file, 1U)
        && signal_audio_write_u32_le(
            file,
            (uint32_t)SIGNAL_AUDIO_EXPORT_SAMPLE_RATE
        )
        && signal_audio_write_u32_le(
            file,
            (uint32_t)SIGNAL_AUDIO_EXPORT_SAMPLE_RATE *
                (uint32_t)sizeof(int16_t)
        )
        && signal_audio_write_u16_le(file, (uint16_t)sizeof(int16_t))
        && signal_audio_write_u16_le(file, 16U)
        && signal_audio_write_bytes(file, data, sizeof(data))
        && signal_audio_write_u32_le(file, data_bytes);
}

int signal_audio_write_wav(const char *path) {
    if (path == NULL) {
        return 0;
    }

    float table[SIGNAL_AUDIO_TABLE_SIZE];
    if (!signal_audio_copy_active_table(table)) return 0;

    FILE *file = fopen(path, "wb");
    if (file == NULL) {
        return 0;
    }

    uint32_t frame_count =
        (uint32_t)SIGNAL_AUDIO_EXPORT_SAMPLE_RATE *
        (uint32_t)SIGNAL_AUDIO_EXPORT_SECONDS;
    int success = signal_audio_write_wav_header(file, frame_count);
    const size_t fade_frames = (size_t)(
        kSignalAudioFadeSeconds * (float)SIGNAL_AUDIO_EXPORT_SAMPLE_RATE
    );
    int16_t samples[SIGNAL_AUDIO_EXPORT_CHUNK_FRAMES];
    float phase = 0.0f;
    size_t frame = 0U;

    while (success != 0 && frame < frame_count) {
        size_t remaining = (size_t)frame_count - frame;
        size_t chunk_frames = remaining;
        if (chunk_frames > SIGNAL_AUDIO_EXPORT_CHUNK_FRAMES) {
            chunk_frames = SIGNAL_AUDIO_EXPORT_CHUNK_FRAMES;
        }

        for (size_t chunk_index = 0U; chunk_index < chunk_frames; chunk_index++) {
            size_t absolute_frame = frame + chunk_index;
            float fade = 1.0f;
            if (fade_frames > 0U && absolute_frame < fade_frames) {
                fade = (float)absolute_frame / (float)fade_frames;
            }

            size_t frames_remaining = (size_t)frame_count - absolute_frame;
            if (fade_frames > 0U && frames_remaining <= fade_frames) {
                float end_fade = (float)(frames_remaining - 1U) /
                    (float)fade_frames;
                if (end_fade < fade) {
                    fade = end_fade;
                }
            }

            float value = signal_audio_wavetable_sample(table, phase);
            value *= kSignalAudioGain * fade;
            value = signal_audio_clamp_sample(value);
            samples[chunk_index] = (int16_t)(value * 32767.0f);
            phase = signal_audio_advance_phase(
                phase,
                kSignalAudioFrequencyHz /
                    (float)SIGNAL_AUDIO_EXPORT_SAMPLE_RATE
            );
        }

        if (
            fwrite(
                samples,
                sizeof(samples[0]),
                chunk_frames,
                file
            ) != chunk_frames
        ) {
            success = 0;
        }
        frame += chunk_frames;
    }

    if (fclose(file) != 0) {
        success = 0;
    }
    return success;
}
