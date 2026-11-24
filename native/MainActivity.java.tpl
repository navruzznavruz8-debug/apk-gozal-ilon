package __PACKAGE__;

import android.Manifest;
import android.app.DownloadManager;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.provider.MediaStore;
import android.util.Base64;
import android.webkit.CookieManager;
import android.webkit.DownloadListener;
import android.webkit.JavascriptInterface;
import android.webkit.MimeTypeMap;
import android.webkit.URLUtil;
import android.webkit.WebView;
import android.widget.Toast;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import com.getcapacitor.BridgeActivity;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import org.json.JSONObject;

public class MainActivity extends BridgeActivity {

    private OutputStream dlOut;
    private String dlName = "";

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        try {
            if (Build.VERSION.SDK_INT < 29
                    && ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE)
                    != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(this,
                        new String[]{Manifest.permission.WRITE_EXTERNAL_STORAGE}, 4242);
            }
            final WebView wv = getBridge().getWebView();
            wv.addJavascriptInterface(new DL(), "AndroidDL");
            wv.setDownloadListener(new DownloadListener() {
                @Override
                public void onDownloadStart(String url, String ua, String cd, String mime, long len) {
                    handleDownload(wv, url, ua, cd, mime);
                }
            });
        } catch (Throwable t) {
            // ilova ishlashda davom etadi
        }
    }

    private void toast(final String msg) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                Toast.makeText(MainActivity.this, msg, Toast.LENGTH_LONG).show();
            }
        });
    }

    private String readAsset(String n) throws Exception {
        InputStream in = getAssets().open(n);
        BufferedReader br = new BufferedReader(new InputStreamReader(in, "UTF-8"));
        StringBuilder sb = new StringBuilder();
        String line;
        while ((line = br.readLine()) != null) {
            sb.append(line).append('\n');
        }
        br.close();
        return sb.toString();
    }

    private void handleDownload(WebView wv, String url, String ua, String cd, String mime) {
        try {
            if (url.startsWith("blob:") || url.startsWith("data:")) {
                String js = readAsset("dl.js");
                String call = "(" + js + ")(" + JSONObject.quote(url) + "," + JSONObject.quote("")
                        + "," + JSONObject.quote(mime == null ? "" : mime) + ")";
                wv.evaluateJavascript(call, null);
            } else if (url.startsWith("http")) {
                String name = URLUtil.guessFileName(url, cd, mime);
                DownloadManager.Request r = new DownloadManager.Request(Uri.parse(url));
                if (mime != null) {
                    r.setMimeType(mime);
                }
                String ck = CookieManager.getInstance().getCookie(url);
                if (ck != null) {
                    r.addRequestHeader("cookie", ck);
                }
                if (ua != null) {
                    r.addRequestHeader("User-Agent", ua);
                }
                r.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
                r.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, name);
                DownloadManager dm = (DownloadManager) getSystemService(Context.DOWNLOAD_SERVICE);
                dm.enqueue(r);
                toast("Yuklanmoqda: " + name);
            }
        } catch (Throwable t) {
            toast("Yuklash xatosi: " + t.getMessage());
        }
    }

    private String cleanName(String name, String mime) {
        String n = name == null ? "" : name.trim();
        n = n.replaceAll("[^A-Za-z0-9._ -]", "_");
        if (n.length() == 0) {
            String ext = null;
            if (mime != null && mime.length() > 0) {
                ext = MimeTypeMap.getSingleton().getExtensionFromMimeType(mime);
            }
            n = "download_" + System.currentTimeMillis() + (ext != null ? "." + ext : "");
        }
        return n;
    }

    private File uniqueFile(File dir, String n) {
        File f = new File(dir, n);
        int i = 1;
        while (f.exists()) {
            int dot = n.lastIndexOf('.');
            String base = dot > 0 ? n.substring(0, dot) : n;
            String ext = dot > 0 ? n.substring(dot) : "";
            f = new File(dir, base + " (" + i + ")" + ext);
            i++;
        }
        return f;
    }

    private void closeQuiet() {
        try {
            if (dlOut != null) {
                dlOut.close();
            }
        } catch (Throwable t) {
            // e'tiborsiz
        }
        dlOut = null;
    }

    public class DL {

        @JavascriptInterface
        public boolean begin(String name, String mime) {
            try {
                closeQuiet();
                String n = cleanName(name, mime);
                dlName = n;
                if (Build.VERSION.SDK_INT >= 29) {
                    ContentValues cv = new ContentValues();
                    cv.put(MediaStore.MediaColumns.DISPLAY_NAME, n);
                    cv.put(MediaStore.MediaColumns.MIME_TYPE, mime);
                    cv.put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS);
                    ContentResolver cr = getContentResolver();
                    Uri uri = cr.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, cv);
                    dlOut = cr.openOutputStream(uri);
                } else {
                    File dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS);
                    dir.mkdirs();
                    File f = uniqueFile(dir, n);
                    dlName = f.getName();
                    dlOut = new FileOutputStream(f);
                }
                return dlOut != null;
            } catch (Throwable t) {
                toast("Saqlash xatosi: " + t.getMessage());
                return false;
            }
        }

        @JavascriptInterface
        public void write(String b64) {
            try {
                if (dlOut != null) {
                    dlOut.write(Base64.decode(b64, Base64.DEFAULT));
                }
            } catch (Throwable t) {
                closeQuiet();
                toast("Yozish xatosi: " + t.getMessage());
            }
        }

        @JavascriptInterface
        public void end() {
            try {
                if (dlOut != null) {
                    dlOut.flush();
                    dlOut.close();
                    dlOut = null;
                    toast("Saqlandi: Yuklanmalar (Download) papkasi / " + dlName);
                }
            } catch (Throwable t) {
                toast("Saqlash xatosi: " + t.getMessage());
            }
        }

        @JavascriptInterface
        public void fail(String msg) {
            closeQuiet();
            toast("Yuklash xatosi: " + msg);
        }
    }
}
