package com.pocketstrike.pocketstrike

import android.content.Context
import java.io.BufferedReader
import java.io.InputStreamReader

/**
 * Tiny shell runner for root-privileged commands.
 *
 * Commands are only executed through `su -c` when the device is rooted;
 * the caller is responsible for deciding whether to invoke privileged
 * actions. Output is captured synchronously and returned as a data class
 * so the Flutter side can surface it as an observation.
 */
data class ShellResult(
    val exitCode: Int,
    val stdout: String,
    val stderr: String
)

object ShellExecutor {

    /**
     * Run a shell command as root.
     *
     * @param context any context (unused but kept for parity with Flutter API).
     * @param cmd the command line, e.g. `su -c "pm list packages"`.
     */
    fun execShell(context: Context, cmd: String): ShellResult {
        return try {
            val process = Runtime.getRuntime().exec(arrayOf("sh", "-c", cmd))
            val stdout = BufferedReader(InputStreamReader(process.inputStream)).use { it.readText() }
            val stderr = BufferedReader(InputStreamReader(process.errorStream)).use { it.readText() }
            val exitCode = process.waitFor()
            ShellResult(exitCode, stdout, stderr)
        } catch (e: Exception) {
            ShellResult(-1, "", e.message ?: "Unknown error")
        }
    }

    /** Convenience for fire-and-forget input injection. */
    fun runShellCommand(context: Context, cmd: String) {
        execShell(context, cmd)
    }
}
