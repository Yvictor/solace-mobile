package com.example.solacepoc;

import android.app.Activity;
import android.os.Bundle;
import android.text.InputType;
import android.util.Log;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public final class MainActivity extends Activity {
    private static final String TAG = "SolaceMobileAndroid";

    private final ExecutorService worker = Executors.newSingleThreadExecutor();

    private EditText hostInput;
    private EditText vpnInput;
    private EditText usernameInput;
    private EditText passwordInput;
    private EditText subscribeTopicInput;
    private EditText publishTopicInput;
    private EditText compressionInput;
    private TextView logView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(buildContentView());
    }

    @Override
    protected void onDestroy() {
        worker.shutdownNow();
        super.onDestroy();
    }

    private ScrollView buildContentView() {
        LinearLayout form = new LinearLayout(this);
        form.setOrientation(LinearLayout.VERTICAL);
        int pad = dp(16);
        form.setPadding(pad, pad, pad, pad);

        hostInput = input("Host, e.g. tcp://host:55555", InputType.TYPE_CLASS_TEXT);
        vpnInput = input("VPN", InputType.TYPE_CLASS_TEXT);
        usernameInput = input("Username", InputType.TYPE_CLASS_TEXT);
        passwordInput = input("Password", InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_PASSWORD);
        subscribeTopicInput = input("Subscribe topic, wildcards allowed", InputType.TYPE_CLASS_TEXT);
        publishTopicInput = input("Publish topic, concrete topic only", InputType.TYPE_CLASS_TEXT);
        compressionInput = input("Compression level 0..9", InputType.TYPE_CLASS_NUMBER);
        compressionInput.setText("3");

        Button runButton = new Button(this);
        runButton.setText("Run native Solace compression PoC");
        runButton.setOnClickListener(v -> runProbe());

        logView = new TextView(this);
        logView.setTextIsSelectable(true);
        logView.setText("Ready.\n");

        form.addView(hostInput);
        form.addView(vpnInput);
        form.addView(usernameInput);
        form.addView(passwordInput);
        form.addView(subscribeTopicInput);
        form.addView(publishTopicInput);
        form.addView(compressionInput);
        form.addView(runButton);
        form.addView(logView);

        ScrollView scroll = new ScrollView(this);
        scroll.addView(form);
        return scroll;
    }

    private EditText input(String hint, int inputType) {
        EditText field = new EditText(this);
        field.setHint(hint);
        field.setSingleLine(true);
        field.setInputType(inputType);
        field.setLayoutParams(new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT));
        return field;
    }

    private void runProbe() {
        appendLog("Starting probe...");
        SolaceProbe.Config config = new SolaceProbe.Config(
                text(hostInput),
                text(vpnInput),
                text(usernameInput),
                text(passwordInput),
                text(subscribeTopicInput),
                text(publishTopicInput),
                parseCompressionLevel());

        worker.execute(() -> {
            try {
                SolaceProbe.Result result = SolaceProbe.run(config);
                Log.i(TAG, result.summary);
                appendLog(result.summary);
            } catch (Throwable t) {
                Log.e(TAG, "Probe failed", t);
                appendLog("FAILED: " + t.getClass().getName() + ": " + t.getMessage());
            }
        });
    }

    private String text(EditText input) {
        return input.getText().toString().trim();
    }

    private int parseCompressionLevel() {
        String value = text(compressionInput);
        if (value.isEmpty()) {
            return 0;
        }
        return Integer.parseInt(value);
    }

    private void appendLog(String line) {
        runOnUiThread(() -> logView.append(line + "\n"));
    }

    private int dp(int value) {
        return (int) (value * getResources().getDisplayMetrics().density);
    }
}
