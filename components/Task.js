import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Checkbox } from 'react-native-paper'; // Import Checkbox from react-native-paper

const Task = (props) => {
    return (
        <View style={styles.item}>
            <View style={styles.itemLeft}>
                <Checkbox
                    status={props.isCompleted ? 'checked' : 'unchecked'}
                    onPress={props.onToggleTask} // Trigger task completion toggle
                />
                <Text style={[styles.itemText, props.isCompleted && styles.completedText]}>
                    {props.text}
                </Text>
            </View>
        </View>
    );
};

const styles = StyleSheet.create({
    item: {
        backgroundColor: '#7161EF',
        padding: 15,
        borderRadius: 10,
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        marginBottom: 20,
    },
    itemLeft: {
        flexDirection: 'row',
        alignItems: 'center',
        flexWrap: 'wrap',
    },
    itemText: {
        maxWidth: '100%',
        color: '#FFF',
        fontSize: 20,
    },
    completedText: {
        textDecorationLine: 'line-through',
        color: '#A9A9A9',
    },
});

export default Task;
