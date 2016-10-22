package com.littocats.storageassistant;

import android.content.Context;
import android.content.SharedPreferences;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteException;
import android.database.sqlite.SQLiteStatement;

import com.facebook.react.ReactPackage;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.JavaScriptModule;
import com.facebook.react.bridge.NativeModule;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableType;
import com.facebook.react.uimanager.ViewManager;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Created by 程巍巍 on 10/21/16.
 */
public class StorageAssistant extends ReactContextBaseJavaModule{

    static String DOMAIN = "com.littocats.storageassistant";

    @Override
    public String getName() {
        return "StorageAssistant";
    }

    private Map<String, SQLiteDatabase> DBM = new HashMap<>();

    public StorageAssistant(ReactApplicationContext reactContext) {
        super(reactContext);
    }

    @Override
    public Map<String, Object> getConstants() {
        final Map<String, Object> constants = new HashMap<>();
        constants.put("Home", getReactApplicationContext().getFilesDir().toString() + "/com.littocats/storageassistant");
        return constants;
    }

    @ReactMethod
    public void sqlite3_open(String dbPath, Callback callback)
    {
        String db = getMD5(dbPath);
        if (!DBM.containsKey(db)) {
            SQLiteDatabase database = getReactApplicationContext().openOrCreateDatabase(getMD5(dbPath), Context.MODE_PRIVATE, null);
            DBM.put(db, database);
        }
        callback.invoke(null, db);
    }

    @ReactMethod
    public void sqlite3_execute(String db, String sql, ReadableArray params, Callback callback)
    {
        SQLiteDatabase database = DBM.get(db);

        List<String> binds = new ArrayList<>();
        int size = params.size();
        for (int index = 0; index < size; index++) {
            ReadableType type = params.getType(index);
            switch (type) {
                case Boolean: {
                    binds.add("" + (params.getBoolean(index) ? 1 : 0));
                }break;
                case Number: {
                    binds.add("" + params.getDouble(index));
                }break;
                case String: {
                    binds.add(params.getString(index));
                }break;
                default: {
                    binds.add("");
                }
            }
        }
        try {
            if (!sql.toUpperCase().startsWith("SELECT")) {
                SQLiteStatement statement = database.compileStatement(sql);
                statement.bindAllArgsAsStrings(binds.toArray(new String[]{}));
                statement.execute();
                callback.invoke();
            }else {
                Cursor cursor = database.rawQuery(sql, binds.toArray(new String[]{}));
                JSONArray results = new JSONArray();

                if (cursor.getCount() > 0) {
                    do {
                        JSONObject row = new JSONObject();
                        int columns = cursor.getColumnCount();
                        for (int column = 0; column < columns; column++) {
                            cursor.moveToPosition(column);

                            String name = cursor.getColumnName(column);
                            int type = cursor.getType(column);
                            switch (type) {
                                case Cursor.FIELD_TYPE_INTEGER: {
                                    long num = cursor.getLong(column);
                                    row.put(name, num);
                                }break;
                                case Cursor.FIELD_TYPE_FLOAT: {
                                    double num = cursor.getDouble(column);
                                    row.put(name, num);
                                }break;
                                case Cursor.FIELD_TYPE_STRING: {
                                    String str = cursor.getString(column);
                                    row.put(name, str);
                                }break;
                                default: break;
                            }
                        }
                        results.put(row);
                    }while (!cursor.isLast());
                }
                callback.invoke(null, results.toString(0));
            }
        }catch (SQLiteException e) {
            callback.invoke(e);
        }catch (JSONException e) {
            callback.invoke(e);
        }

    }

    @ReactMethod
    public void sqlite3_close(String db, Callback callback)
    {
        SQLiteDatabase database = DBM.get(db);
        if (database != null){
            DBM.remove(db);
            database.close();
        }
        callback.invoke();
    }


    public static String getMD5(String val)  {
        val = "" + val;
        MessageDigest md5 = null;
        try {
            md5 = MessageDigest.getInstance("MD5");
        } catch (NoSuchAlgorithmException e) {
            e.printStackTrace();
        }
        md5.update(val.getBytes());
        byte[] m = md5.digest();//加密

        StringBuffer sb = new StringBuffer();
        for(int i = 0; i < m.length; i ++){
            sb.append(m[i]);
        }
        return sb.toString();
    }

    @ReactMethod
    public void keychain_Put(String account, String password, String service, Boolean updateExisting, Callback callback)
    {
        account = getMD5(account);
        service = getMD5(service != null ? service : DOMAIN);

        SharedPreferences preferences = getReactApplicationContext().getSharedPreferences(service, Context.MODE_PRIVATE);
        try {
            {
                String cpwd = preferences.getString(account, null);
                if (cpwd != null) {
                    if (!updateExisting) {
                        throw new Exception("KeyChain item already exists.");
                    }
                    SharedPreferences.Editor editor = preferences.edit();
                    editor.remove(account);
                    editor.apply();
                }
            }
            SharedPreferences.Editor editor = preferences.edit();
            editor.putString(account, password);
            editor.apply();
        }catch (Exception e) {
            callback.invoke(e);
        }
    }

    @ReactMethod
    public void keychain_Get(String account, String service, Callback callback)
    {
        try {
            account = getMD5(account);
            service = getMD5(service != null ? service : DOMAIN);
            SharedPreferences preferences = getReactApplicationContext().getSharedPreferences(service, Context.MODE_PRIVATE);
            String password = preferences.getString(account, null);
            if (password == null ) callback.invoke(); else callback.invoke(null, password);
        }catch (Exception e) {
            callback.invoke(e);
        }
    }

    @ReactMethod
    public void keychain_Remove(String account, String service, Callback callback)
    {
        try {
            account = getMD5(account);
            service = getMD5(service != null ? service : DOMAIN);

            SharedPreferences preferences = getReactApplicationContext().getSharedPreferences(service, Context.MODE_PRIVATE);
            SharedPreferences.Editor editor = preferences.edit();
            editor.remove(account);
            editor.apply();
        }catch (Exception e) {
            callback.invoke(e);
        }
    }

    public static class ModulePackage implements ReactPackage {
        @Override
        public List<NativeModule> createNativeModules(ReactApplicationContext reactContext) {
            List<NativeModule> modules = new ArrayList<>();

            modules.add(new StorageAssistant(reactContext));

            return modules;
        }

        @Override
        public List<Class<? extends JavaScriptModule>> createJSModules() {
            return Collections.emptyList();
        }

        @Override
        public List<ViewManager> createViewManagers(ReactApplicationContext reactContext) {
            return Collections.emptyList();
        }
    }
}
