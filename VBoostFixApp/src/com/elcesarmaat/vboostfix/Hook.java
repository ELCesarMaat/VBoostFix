package com.elcesarmaat.vboostfix;

import android.util.Log;

import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import de.robv.android.xposed.IXposedHookLoadPackage;
import de.robv.android.xposed.XC_MethodHook;
import de.robv.android.xposed.XposedBridge;
import de.robv.android.xposed.XposedHelpers;
import de.robv.android.xposed.callbacks.XC_LoadPackage;

/**
 * Cambia el modelo del DeviceInfo de la llamada PhotosCreateMediaItems solo cuando el archivo es un
 * Video Boost crudo (PXL_...VB-02...mp4). El resto de subidas sigue saliendo con la identidad de Pixelify.
 *
 * Nombres ofuscados de Google Fotos 7.96.0.996044120 (versionCode 52514915); ver ingenieria_inversa_fotos_7.96.md.
 */
public class Hook implements IXposedHookLoadPackage {

    private static final String TAG = "VBoostFix";
    private static final String PHOTOS = "com.google.android.apps.photos";

    /** Peticion de PhotosCreateMediaItems (implementa cggr); su constructor recibe un cshs. */
    private static final String CLS_REQUEST = "blkg";
    private static final String CLS_REQUEST_ARG = "cshs";
    /** blkg.c: lista de cndi (MediaItemBlueprint). */
    private static final String F_ITEMS = "c";
    /** blkg.e: cjtj (DeviceInfo). */
    private static final String F_DEVICE = "e";
    /** cndi.k: nombre del archivo (el mismo que X-Goog-Upload-File-Name). */
    private static final String F_FILENAME = "k";
    /** cjtj.d: model; cjtj.e: manufacturer. */
    private static final String F_MODEL = "d";
    private static final String F_MANUFACTURER = "e";

    /** Si es true, tambien se cambia la identidad al crear el COVER (VB-01). */
    private static final boolean INCLUDE_COVER = false;

    /** Mismo criterio que cjey.PIXEL_BLANFORD: numero 3 = ya procesado, grupo 2 = COVER. */
    private static final Pattern BOOST =
            Pattern.compile("(?i)^(?:PXL|PIXEL)_[^.]*\\.[^\\d-]*VB-(\\d+)(\\.[^/]*COVER)?.*\\.mp4$");

    private static String realModel = "Pixel 9 Pro XL";
    private static String realManufacturer = "Google";

    private static void log(String msg) {
        XposedBridge.log(TAG + ": " + msg);
        Log.i(TAG, msg);
    }

    private static String sysprop(String key) {
        try {
            Class<?> c = Class.forName("android.os.SystemProperties");
            Method get = c.getMethod("get", String.class);
            String v = (String) get.invoke(null, key);
            return (v == null || v.isEmpty()) ? null : v;
        } catch (Throwable t) {
            return null;
        }
    }

    /** 0 = no es boost; 1 = boost que se debe cambiar; 2 = boost que se deja igual (COVER o procesado). */
    static int classify(String name) {
        if (name == null) return 0;
        Matcher m = BOOST.matcher(name);
        if (!m.matches()) return 0;
        boolean processed = "3".equals(m.group(1).replaceFirst("^0+", ""));
        boolean cover = m.group(2) != null;
        if (processed) return 2;
        if (cover && !INCLUDE_COVER) return 2;
        return 1;
    }

    @Override
    public void handleLoadPackage(XC_LoadPackage.LoadPackageParam lpparam) {
        if (!PHOTOS.equals(lpparam.packageName)) return;

        String model = sysprop("ro.product.model");
        String manufacturer = sysprop("ro.product.manufacturer");
        if (model != null) realModel = model;
        if (manufacturer != null) realManufacturer = manufacturer;

        try {
            XposedHelpers.findAndHookConstructor(CLS_REQUEST, lpparam.classLoader, CLS_REQUEST_ARG,
                    new XC_MethodHook() {
                        @Override
                        protected void afterHookedMethod(MethodHookParam param) {
                            onCreateMediaItems(param.thisObject);
                        }
                    });
            log("cargado en " + lpparam.processName + "; modelo real=" + realModel + " (" + realManufacturer + ")"
                    + (model == null ? " [valor por defecto]" : ""));
        } catch (Throwable t) {
            log("no se pudo enganchar " + CLS_REQUEST + "(" + CLS_REQUEST_ARG + ") en " + lpparam.processName
                    + ": " + t + ". Esta version de Fotos no coincide; no se cambia nada.");
        }
    }

    private static void onCreateMediaItems(Object request) {
        try {
            Object items = XposedHelpers.getObjectField(request, F_ITEMS);
            Object device = XposedHelpers.getObjectField(request, F_DEVICE);
            if (!(items instanceof List) || device == null) {
                log("PhotosCreateMediaItems: estructura inesperada (items=" + items + ", device=" + device + "); sin cambio");
                return;
            }
            List<?> list = (List<?>) items;
            List<String> names = new ArrayList<>();
            int change = 0;
            int keep = 0;
            for (Object item : list) {
                String name = (String) XposedHelpers.getObjectField(item, F_FILENAME);
                names.add(name);
                int c = classify(name);
                if (c == 1) change++;
                else if (c == 2) keep++;
            }
            String sentModel = (String) XposedHelpers.getObjectField(device, F_MODEL);

            if (change > 0 && change == list.size()) {
                XposedHelpers.setObjectField(device, F_MODEL, realModel);
                XposedHelpers.setObjectField(device, F_MANUFACTURER, realManufacturer);
                log("PhotosCreateMediaItems " + names + ": modelo " + sentModel + " -> " + realModel);
            } else if (change > 0) {
                log("PhotosCreateMediaItems " + names + ": lote mixto (" + change + " boost de " + list.size()
                        + "); sin cambio, modelo=" + sentModel);
            } else {
                log("PhotosCreateMediaItems " + names + ": sin cambio, modelo=" + sentModel
                        + (keep > 0 ? " (boost que no se cambia)" : ""));
            }
        } catch (Throwable t) {
            log("PhotosCreateMediaItems: error, sin cambio: " + t);
        }
    }
}
